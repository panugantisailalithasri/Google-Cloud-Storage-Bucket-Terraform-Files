#!/usr/bin/env python3
"""
ECS backend deployment health checker.

Runs the standard suite of checks for a backend (ECS) service and emits a
structured JSON (or human-readable text) report.

Checks performed
----------------
 1  cluster_exists              Cluster exists and is ACTIVE
 2  service_exists              Service exists and is ACTIVE
 3  primary_deployment          Primary deployment rolloutState is COMPLETED
 4  running_equals_desired      runningCount == desiredCount
 5  pending_count               pendingCount == 0 (unless --allow-pending)
 6  no_failure_events           No failure keywords in recent service events
 7  task_definition_revision    Current TD matches --expected-revision (if given)
 8  tasks_use_current_td        All running tasks use the service's current TD
 9  containers_running          All (or required) containers are RUNNING
10  no_stopped_failed_tasks     No failed/stopped tasks within --lookback-minutes
11  task_health                 HEALTHY→PASS  UNHEALTHY→FAIL  UNKNOWN→NOT_APPLICABLE
12  alb_target_health           All ALB targets healthy (NOT_APPLICABLE if no LB)

Exit codes
----------
  0  all checks PASS or NOT_APPLICABLE
  1  one or more checks FAIL (or WARNING with --fail-on-warning)
  2  cluster or service not found (early exit)
"""

import argparse
import json
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import boto3
from botocore.exceptions import ClientError

# ── Status labels ─────────────────────────────────────────────────────────────
PASS = "PASS"
FAIL = "FAIL"
NOT_APPLICABLE = "NOT_APPLICABLE"
WARNING = "WARNING"

_ICONS = {PASS: "✔", FAIL: "✖", WARNING: "⚠", NOT_APPLICABLE: "–"}


# ── Data types ────────────────────────────────────────────────────────────────

@dataclass
class CheckResult:
    check: str
    status: str
    message: str
    detail: Optional[Dict[str, Any]] = field(default=None)


def _overall(results: List[CheckResult]) -> str:
    statuses = {r.status for r in results}
    if FAIL in statuses:
        return FAIL
    if WARNING in statuses:
        return WARNING
    return PASS


# ── Check 1: Cluster ──────────────────────────────────────────────────────────

def check_cluster_exists(ecs, cluster: str) -> CheckResult:
    try:
        resp = ecs.describe_clusters(clusters=[cluster])
    except ClientError as exc:
        return CheckResult("cluster_exists", FAIL, str(exc))

    active = [c for c in resp.get("clusters", []) if c["status"] != "INACTIVE"]
    if not active:
        return CheckResult("cluster_exists", FAIL, f"Cluster '{cluster}' not found or INACTIVE.")
    status = active[0]["status"]
    if status != "ACTIVE":
        return CheckResult(
            "cluster_exists", FAIL,
            f"Cluster '{cluster}' status is {status}, expected ACTIVE.",
            {"status": status},
        )
    return CheckResult("cluster_exists", PASS, f"Cluster '{cluster}' is ACTIVE.")


# ── Check 2: Service ──────────────────────────────────────────────────────────

def check_service_exists(ecs, cluster: str, service: str):
    """Returns (CheckResult, service_dict | None)."""
    try:
        resp = ecs.describe_services(cluster=cluster, services=[service])
    except ClientError as exc:
        return CheckResult("service_exists", FAIL, str(exc)), None

    active = [s for s in resp.get("services", []) if s["status"] != "INACTIVE"]
    if not active:
        return (
            CheckResult(
                "service_exists", FAIL,
                f"Service '{service}' not found or INACTIVE in cluster '{cluster}'.",
            ),
            None,
        )
    svc = active[0]
    if svc["status"] != "ACTIVE":
        return (
            CheckResult(
                "service_exists", FAIL,
                f"Service '{service}' status is {svc['status']}, expected ACTIVE.",
                {"status": svc["status"]},
            ),
            svc,
        )
    return CheckResult("service_exists", PASS, f"Service '{service}' is ACTIVE."), svc


# ── Check 3: Primary deployment rollout ───────────────────────────────────────

def check_primary_deployment(svc: dict) -> CheckResult:
    primary = next(
        (d for d in svc.get("deployments", []) if d["status"] == "PRIMARY"), None
    )
    if not primary:
        return CheckResult("primary_deployment", FAIL, "No PRIMARY deployment found.")

    rollout = primary.get("rolloutState", "UNKNOWN")
    detail = {
        "rolloutState": rollout,
        "rolloutStateReason": primary.get("rolloutStateReason", ""),
        "runningCount": primary.get("runningCount"),
        "desiredCount": primary.get("desiredCount"),
        "pendingCount": primary.get("pendingCount"),
    }
    if rollout == "COMPLETED":
        return CheckResult("primary_deployment", PASS, "Primary deployment rollout is COMPLETED.", detail)
    if rollout == "IN_PROGRESS":
        return CheckResult(
            "primary_deployment", WARNING,
            f"Rollout IN_PROGRESS. Reason: {primary.get('rolloutStateReason', '')}",
            detail,
        )
    return CheckResult(
        "primary_deployment", FAIL,
        f"Rollout state is {rollout}. Reason: {primary.get('rolloutStateReason', '')}",
        detail,
    )


# ── Check 4: runningCount == desiredCount ────────────────────────────────────

def check_running_equals_desired(svc: dict) -> CheckResult:
    running = svc.get("runningCount", 0)
    desired = svc.get("desiredCount", 0)
    detail = {"runningCount": running, "desiredCount": desired}
    if running == desired:
        return CheckResult(
            "running_equals_desired", PASS,
            f"runningCount ({running}) == desiredCount ({desired}).",
            detail,
        )
    return CheckResult(
        "running_equals_desired", FAIL,
        f"runningCount ({running}) != desiredCount ({desired}).",
        detail,
    )


# ── Check 5: pendingCount == 0 ───────────────────────────────────────────────

def check_pending_count(svc: dict, allow_pending: bool = False) -> CheckResult:
    pending = svc.get("pendingCount", 0)
    detail = {"pendingCount": pending}
    if pending == 0:
        return CheckResult("pending_count", PASS, "pendingCount is 0.")
    if allow_pending:
        return CheckResult(
            "pending_count", WARNING,
            f"pendingCount is {pending} (allowed via --allow-pending).",
            detail,
        )
    return CheckResult(
        "pending_count", FAIL,
        f"pendingCount is {pending}, expected 0.",
        detail,
    )


# ── Check 6: No failure-related events ───────────────────────────────────────

_FAILURE_KEYWORDS = (
    "unable", "failed", "error", "insufficient", "unhealthy",
    "throttl", "stopped", "oom", "kill", "exit code",
)


def check_no_failure_events(svc: dict, lookback_minutes: int = 60) -> CheckResult:
    cutoff = datetime.now(tz=timezone.utc) - timedelta(minutes=lookback_minutes)
    failures = []
    for event in svc.get("events", []):
        created = event.get("createdAt")
        if created and created.replace(tzinfo=timezone.utc) < cutoff:
            break
        msg = event.get("message", "").lower()
        if any(kw in msg for kw in _FAILURE_KEYWORDS):
            failures.append({
                "createdAt": str(event.get("createdAt")),
                "message": event.get("message"),
            })

    if not failures:
        return CheckResult(
            "no_failure_events", PASS,
            f"No failure-related events in the last {lookback_minutes} minutes.",
        )
    return CheckResult(
        "no_failure_events", FAIL,
        f"{len(failures)} failure-related event(s) in the last {lookback_minutes} minutes.",
        {"events": failures[:10]},
    )


# ── Check 7: Task definition revision ────────────────────────────────────────

def check_task_definition_revision(svc: dict, expected_revision: Optional[str]) -> CheckResult:
    current_td = svc.get("taskDefinition", "")
    if not expected_revision:
        return CheckResult(
            "task_definition_revision", NOT_APPLICABLE,
            f"No expected revision specified. Current: {current_td}",
            {"current": current_td},
        )
    if expected_revision in current_td:
        return CheckResult(
            "task_definition_revision", PASS,
            f"Task definition matches expected '{expected_revision}'.",
            {"current": current_td, "expected": expected_revision},
        )
    return CheckResult(
        "task_definition_revision", FAIL,
        f"Task definition mismatch. Current: {current_td}  Expected: {expected_revision}",
        {"current": current_td, "expected": expected_revision},
    )


# ── Check 8: All running tasks use current TD ────────────────────────────────

def check_tasks_use_current_td(ecs, cluster: str, service: str, svc: dict) -> CheckResult:
    current_td = svc.get("taskDefinition", "")
    try:
        task_arns = _list_all_tasks(ecs, cluster, service, "RUNNING")
    except ClientError as exc:
        return CheckResult("tasks_use_current_td", FAIL, str(exc))

    if not task_arns:
        return CheckResult(
            "tasks_use_current_td", WARNING,
            "No running tasks found to verify task definition.",
        )

    stale = []
    for batch in _chunks(task_arns, 100):
        for task in ecs.describe_tasks(cluster=cluster, tasks=batch).get("tasks", []):
            if task.get("taskDefinitionArn") != current_td:
                stale.append({
                    "taskArn": task.get("taskArn"),
                    "taskDefinition": task.get("taskDefinitionArn"),
                })

    if not stale:
        return CheckResult(
            "tasks_use_current_td", PASS,
            f"All {len(task_arns)} running task(s) use the current task definition.",
            {"currentTd": current_td, "taskCount": len(task_arns)},
        )
    return CheckResult(
        "tasks_use_current_td", FAIL,
        f"{len(stale)} of {len(task_arns)} running task(s) use a stale task definition.",
        {"currentTd": current_td, "staleTasks": stale},
    )


# ── Check 9: Required containers are RUNNING ─────────────────────────────────

def check_containers_running(
    ecs, cluster: str, service: str,
    required_containers: Optional[List[str]] = None,
) -> CheckResult:
    try:
        task_arns = _list_all_tasks(ecs, cluster, service, "RUNNING")
    except ClientError as exc:
        return CheckResult("containers_running", FAIL, str(exc))

    if not task_arns:
        return CheckResult("containers_running", FAIL, "No running tasks found.")

    not_running = []
    for batch in _chunks(task_arns, 100):
        for task in ecs.describe_tasks(cluster=cluster, tasks=batch).get("tasks", []):
            for container in task.get("containers", []):
                name = container.get("name")
                if required_containers and name not in required_containers:
                    continue
                if container.get("lastStatus") != "RUNNING":
                    not_running.append({
                        "taskArn": task.get("taskArn"),
                        "container": name,
                        "lastStatus": container.get("lastStatus"),
                        "reason": container.get("reason", ""),
                    })

    if not not_running:
        label = f"({', '.join(required_containers)})" if required_containers else "(all)"
        return CheckResult(
            "containers_running", PASS,
            f"All required containers {label} are RUNNING.",
        )
    return CheckResult(
        "containers_running", FAIL,
        f"{len(not_running)} container(s) not in RUNNING state.",
        {"notRunning": not_running},
    )


# ── Check 10: No recently stopped/failed tasks ───────────────────────────────

_FAILURE_STOP_CODES = {
    "TaskFailedToStart",
    "EssentialContainerExited",
    "OutOfMemory",
    "SpotInterruption",
    "CannotPullContainerError",
}
_FAILURE_REASON_KEYWORDS = (
    "error", "failed", "oom", "kill", "signal", "exit code", "cannot",
)


def check_no_stopped_failed_tasks(ecs, cluster: str, service: str, lookback_minutes: int = 60) -> CheckResult:
    try:
        task_arns = _list_all_tasks(ecs, cluster, service, "STOPPED")
    except ClientError as exc:
        return CheckResult("no_stopped_failed_tasks", FAIL, str(exc))

    if not task_arns:
        return CheckResult(
            "no_stopped_failed_tasks", PASS,
            "No stopped tasks found.",
        )

    cutoff = datetime.now(tz=timezone.utc) - timedelta(minutes=lookback_minutes)
    failed = []
    for batch in _chunks(task_arns, 100):
        for task in ecs.describe_tasks(cluster=cluster, tasks=batch).get("tasks", []):
            stopped_at = task.get("stoppedAt")
            if stopped_at and _aware(stopped_at) < cutoff:
                continue
            stop_code = task.get("stopCode", "")
            stop_reason = (task.get("stoppedReason") or "").lower()
            if stop_code in _FAILURE_STOP_CODES or any(kw in stop_reason for kw in _FAILURE_REASON_KEYWORDS):
                failed.append({
                    "taskArn": task.get("taskArn"),
                    "stopCode": stop_code,
                    "stoppedReason": task.get("stoppedReason"),
                    "stoppedAt": str(stopped_at),
                })

    if not failed:
        return CheckResult(
            "no_stopped_failed_tasks", PASS,
            f"No failure-stopped tasks in the last {lookback_minutes} minutes.",
        )
    return CheckResult(
        "no_stopped_failed_tasks", FAIL,
        f"{len(failed)} failed/stopped task(s) in the last {lookback_minutes} minutes.",
        {"failedTasks": failed[:20]},
    )


# ── Check 11: Task health ─────────────────────────────────────────────────────

def check_task_health(ecs, cluster: str, service: str) -> CheckResult:
    try:
        task_arns = _list_all_tasks(ecs, cluster, service, "RUNNING")
    except ClientError as exc:
        return CheckResult("task_health", FAIL, str(exc))

    if not task_arns:
        return CheckResult("task_health", NOT_APPLICABLE, "No running tasks to evaluate.")

    healthy, unhealthy, unknown = [], [], []
    for batch in _chunks(task_arns, 100):
        for task in ecs.describe_tasks(cluster=cluster, tasks=batch).get("tasks", []):
            h = task.get("healthStatus", "UNKNOWN")
            if h == "HEALTHY":
                healthy.append(task.get("taskArn"))
            elif h == "UNHEALTHY":
                unhealthy.append({"taskArn": task.get("taskArn"), "healthStatus": h})
            else:
                unknown.append(task.get("taskArn"))

    if unhealthy:
        return CheckResult(
            "task_health", FAIL,
            f"{len(unhealthy)} task(s) are UNHEALTHY.",
            {"unhealthyTasks": unhealthy, "healthyCount": len(healthy)},
        )
    if not healthy:
        return CheckResult(
            "task_health", NOT_APPLICABLE,
            "No task-level health checks configured (all tasks report UNKNOWN/absent).",
            {"unknownCount": len(unknown)},
        )
    return CheckResult(
        "task_health", PASS,
        f"All {len(healthy)} running task(s) are HEALTHY.",
        {"healthyCount": len(healthy), "unknownCount": len(unknown)},
    )


# ── Check 12: ALB target group health ────────────────────────────────────────

def check_alb_target_health(elbv2, svc: dict) -> CheckResult:
    load_balancers = svc.get("loadBalancers", [])
    if not load_balancers:
        return CheckResult(
            "alb_target_health", NOT_APPLICABLE,
            "No load balancer attached to this service.",
        )

    all_unhealthy = []
    all_unregistered = []
    tg_summary = []

    for lb in load_balancers:
        tg_arn = lb.get("targetGroupArn")
        if not tg_arn:
            continue
        try:
            resp = elbv2.describe_target_health(TargetGroupArn=tg_arn)
        except ClientError as exc:
            return CheckResult("alb_target_health", FAIL, f"Error querying {tg_arn}: {exc}")

        descs = resp.get("TargetHealthDescriptions", [])
        if not descs:
            all_unregistered.append(tg_arn)
            tg_summary.append({"targetGroupArn": tg_arn, "registeredTargets": 0})
            continue

        unhealthy = [
            {
                "target": h["Target"],
                "state": h["TargetHealth"]["State"],
                "reason": h["TargetHealth"].get("Reason", ""),
                "description": h["TargetHealth"].get("Description", ""),
            }
            for h in descs
            if h["TargetHealth"]["State"] not in ("healthy", "initial")
        ]
        healthy_count = sum(1 for h in descs if h["TargetHealth"]["State"] == "healthy")
        tg_summary.append({
            "targetGroupArn": tg_arn,
            "registeredTargets": len(descs),
            "healthyTargets": healthy_count,
            "unhealthyTargets": len(unhealthy),
        })
        all_unhealthy.extend(unhealthy)

    if all_unregistered:
        return CheckResult(
            "alb_target_health", FAIL,
            f"No targets registered in: {all_unregistered}",
            {"targetGroups": tg_summary},
        )
    if all_unhealthy:
        return CheckResult(
            "alb_target_health", FAIL,
            f"{len(all_unhealthy)} ALB target(s) are not healthy.",
            {"unhealthyTargets": all_unhealthy, "targetGroups": tg_summary},
        )
    return CheckResult(
        "alb_target_health", PASS,
        "All ALB targets are healthy.",
        {"targetGroups": tg_summary},
    )


# ── Orchestrator ──────────────────────────────────────────────────────────────

def run_checks(
    cluster: str,
    service: str,
    region: str,
    expected_revision: Optional[str] = None,
    required_containers: Optional[List[str]] = None,
    allow_pending: bool = False,
    lookback_minutes: int = 60,
) -> dict:
    session = boto3.session.Session(region_name=region)
    ecs = session.client("ecs")
    elbv2 = session.client("elbv2")

    results: List[CheckResult] = []

    c1 = check_cluster_exists(ecs, cluster)
    results.append(c1)
    if c1.status == FAIL:
        return _build_report(cluster, service, results)

    c2, svc = check_service_exists(ecs, cluster, service)
    results.append(c2)
    if c2.status == FAIL or svc is None:
        return _build_report(cluster, service, results)

    results.append(check_primary_deployment(svc))
    results.append(check_running_equals_desired(svc))
    results.append(check_pending_count(svc, allow_pending=allow_pending))
    results.append(check_no_failure_events(svc, lookback_minutes=lookback_minutes))
    results.append(check_task_definition_revision(svc, expected_revision))
    results.append(check_tasks_use_current_td(ecs, cluster, service, svc))
    results.append(check_containers_running(ecs, cluster, service, required_containers))
    results.append(check_no_stopped_failed_tasks(ecs, cluster, service, lookback_minutes=lookback_minutes))
    results.append(check_task_health(ecs, cluster, service))
    results.append(check_alb_target_health(elbv2, svc))

    return _build_report(cluster, service, results)


def _build_report(cluster: str, service: str, results: List[CheckResult]) -> dict:
    return {
        "cluster": cluster,
        "service": service,
        "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        "overall": _overall(results),
        "checks": [asdict(r) for r in results],
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="ECS backend deployment health checker",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--cluster", required=True, help="ECS cluster name or ARN")
    parser.add_argument("--service", required=True, help="ECS service name or ARN")
    parser.add_argument("--region", default="us-east-1", help="AWS region (default: us-east-1)")
    parser.add_argument(
        "--expected-revision",
        help="Expected task definition family:revision or full ARN",
    )
    parser.add_argument(
        "--required-containers",
        nargs="*",
        help="Container names that must be RUNNING (default: all containers)",
    )
    parser.add_argument(
        "--allow-pending",
        action="store_true",
        help="Treat pendingCount > 0 as WARNING instead of FAIL",
    )
    parser.add_argument(
        "--lookback-minutes",
        type=int,
        default=60,
        help="Minutes to look back for events and stopped tasks (default: 60)",
    )
    parser.add_argument(
        "--output",
        choices=["json", "text"],
        default="json",
        help="Output format (default: json)",
    )
    parser.add_argument(
        "--fail-on-warning",
        action="store_true",
        help="Exit with code 1 if any check is WARNING",
    )
    args = parser.parse_args()

    report = run_checks(
        cluster=args.cluster,
        service=args.service,
        region=args.region,
        expected_revision=args.expected_revision,
        required_containers=args.required_containers,
        allow_pending=args.allow_pending,
        lookback_minutes=args.lookback_minutes,
    )

    if args.output == "json":
        print(json.dumps(report, indent=2, default=str))
    else:
        _print_text(report)

    overall = report["overall"]
    if overall == FAIL or (overall == WARNING and args.fail_on_warning):
        sys.exit(1)
    sys.exit(0)


def _print_text(report: dict) -> None:
    w = 66
    print(f"\n{'=' * w}")
    print(f"  ECS Health Check  [{report['overall']}]")
    print(f"  Cluster  : {report['cluster']}")
    print(f"  Service  : {report['service']}")
    print(f"  Time     : {report['timestamp']}")
    print(f"{'=' * w}")
    for c in report["checks"]:
        icon = _ICONS.get(c["status"], "?")
        print(f"  {icon} [{c['status']:<14}]  {c['check']}")
        print(f"             {c['message']}")
        if c.get("detail"):
            for k, v in c["detail"].items():
                if isinstance(v, list) and v:
                    print(f"             {k}:")
                    for item in v[:5]:
                        print(f"               · {item}")
                elif v is not None:
                    print(f"             {k}: {v}")
    print(f"{'=' * w}")
    print(f"  Overall: {report['overall']}\n")


# ── Helpers ───────────────────────────────────────────────────────────────────

def _list_all_tasks(ecs, cluster: str, service: str, desired_status: str) -> List[str]:
    arns: List[str] = []
    paginator = ecs.get_paginator("list_tasks")
    for page in paginator.paginate(
        cluster=cluster, serviceName=service, desiredStatus=desired_status
    ):
        arns.extend(page.get("taskArns", []))
    return arns


def _chunks(lst: list, n: int):
    for i in range(0, len(lst), n):
        yield lst[i : i + n]


def _aware(dt: datetime) -> datetime:
    """Ensure a datetime is timezone-aware (UTC)."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


if __name__ == "__main__":
    main()
