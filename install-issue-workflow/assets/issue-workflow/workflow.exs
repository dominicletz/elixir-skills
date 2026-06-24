#!/usr/bin/env elixir
# Advances GitHub workflow labels per .cursor/issue-workflow/README.md (cron / every ~5 min).

Mix.install([:jason])

defmodule IssueWorkflow do
  @moduledoc false

  @list_limit 500
  @wait_seconds 3600
  @gh_retry_max_attempts 5

  @ci_fix_marker ~r/<!--\s*cursor-workflow:ci-fix\s+head=([a-f0-9]{40})\s*-->/
  @demo_marker ~r/<!--\s*cursor-workflow:demo\s+head=([a-f0-9]{40})\s*-->/

  @label_not_found ~r/['"]([^'"]+)['"]\s+not found/i

  def run do
    case System.argv() do
      ["--create-labels"] ->
        log("create-labels mode (no workflow run)")
        n = create_labels()
        log("create_labels: created #{n} label(s); exiting")

      _ ->
        run_workflow()
    end
  end

  def create_labels do
    existing =
      gh!(["label", "list", "-L", "500", "--json", "name"], @gh_retry_max_attempts, false)
      |> Jason.decode!()
      |> MapSet.new(& &1["name"])

    missing = Enum.reject(workflow_label_names(), &MapSet.member?(existing, &1))

    Enum.reduce(missing, 0, fn name, acc ->
      log("create_labels: creating #{inspect(name)}")
      color = "C5DEF5"
      desc = "Cursor issue-workflow (.cursor/issue-workflow/README.md)"

      _ =
        gh!(
          ["label", "create", name, "-c", color, "-d", desc],
          @gh_retry_max_attempts,
          false
        )

      acc + 1
    end)
  end

  defp workflow_label_names do
    [
      "cursor-plan",
      "cursor-pick",
      "cursor-pr-open",
      "cursor-ignore",
      "cursor-waiting",
      "cursor-waiting-for-ci",
      "cursor-demo",
      "cursor-waiting-for-human"
    ]
  end

  defp run_workflow do
    log("workflow start")
    slug = repo_slug()
    log("repository #{slug}")
    [owner, repo] = String.split(slug, "/", parts: 2)

    {plans_raw, plans} = list_labeled("issue", "cursor-plan")
    {picks_raw, picks} = list_labeled("issue", "cursor-pick")
    {waits_raw, waits} = list_labeled("pr", "cursor-waiting")
    {ci_raw, ci} = list_labeled("pr", "cursor-waiting-for-ci")
    {demo_raw, demo} = list_labeled("pr", "cursor-demo")

    log_queue("issues label=cursor-plan", plans_raw, plans)
    log_queue("issues label=cursor-pick", picks_raw, picks)
    log_queue("PRs label=cursor-waiting", waits_raw, waits)
    log_queue("PRs label=cursor-waiting-for-ci", ci_raw, ci)
    log_queue("PRs label=cursor-demo", demo_raw, demo)

    Enum.each(plans, &advance_plan(&1["number"]))
    Enum.each(picks, &advance_pick(&1["number"]))
    Enum.each(waits, &advance_waiting(owner, repo, &1["number"]))
    Enum.each(ci, &advance_waiting_for_ci(owner, repo, &1["number"]))
    Enum.each(demo, &advance_demo(owner, repo, &1["number"]))
    log("workflow finished")
  end

  defp list_labeled(kind, label) do
    raw =
      gh!([
        kind,
        "list",
        "--state",
        "open",
        "--label",
        label,
        "-L",
        "#{@list_limit}",
        "--json",
        "number,labels"
      ])
      |> Jason.decode!()

    {raw, reject_if_ignore(raw)}
  end

  defp log(message) do
    IO.puts("[#{iso_timestamp_now()}] #{message}")
  end

  defp iso_timestamp_now do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end

  defp repo_slug do
    case System.get_env("GITHUB_REPOSITORY") do
      nil ->
        gh!(["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"]) |> String.trim()

      slug ->
        slug
    end
  end

  defp reject_if_ignore(items) do
    Enum.reject(items, fn item ->
      Enum.any?(item["labels"] || [], &(&1["name"] == "cursor-ignore"))
    end)
  end

  defp log_queue(title, raw, filtered) do
    log(
      "#{title}: #{length(raw)} matched, #{length(raw) - length(filtered)} skipped (cursor-ignore), #{length(filtered)} to process #{inspect(Enum.map(filtered, & &1["number"]))}"
    )
  end

  defp advance_plan(n) do
    num = to_string(n)
    log("cursor-plan ##{num}: action remove-label cursor-plan")
    gh!(["issue", "edit", num, "--remove-label", "cursor-plan"])
    log("cursor-plan ##{num}: action issue comment (@cursor design + cursor-pick handoff)")
    gh!(["issue", "comment", num, "--body", workflow_plan_comment_body()])
    log("cursor-plan ##{num}: transition complete (agent adds `cursor-pick` when done)")
  end

  defp workflow_plan_comment_body do
    "@cursor review the issue description and comments and then create a comprehensive feature design and description. When doing so take into consideration the current product documentation and feature-set, market and user-experience standards. The feature plan and design need to be consistent with the existing product, and not bolt something alien on-top. Then post the plan here as github comment and add the label `cursor-pick`"
  end

  defp advance_pick(n) do
    num = to_string(n)
    log("cursor-pick ##{num}: action remove-label cursor-pick")
    gh!(["issue", "edit", num, "--remove-label", "cursor-pick"])
    log("cursor-pick ##{num}: action issue comment (@cursoragent + guidelines)")
    gh!(["issue", "comment", num, "--body", workflow_pick_comment_body()])
    log("cursor-pick ##{num}: action add-label cursor-pr-open")
    gh!(["issue", "edit", num, "--add-label", "cursor-pr-open"])
    log("cursor-pick ##{num}: transition complete")
  end

  defp workflow_pick_comment_body do
    """
    @cursor Read the issue description and investigate this issue. Plan how this issue could be addressed
    in a proper fashion then propose a solution as PR.

    Guidelines:
    1. If this issue is a bug then create a minimal code fix - some network errors, e.g. server closing the connection can not
    be "fixed" but need a retry or log a warning. If this issue is a feature first create a comprehensive plan.
    2a. For bugs explain the reasoning behind the bugfix, explain how this addresses the root cause and not
    just "tapes it over"
    2b. For features explain the approach of implementing the feature and how it addresses the business case
    3. Create a unit test case that works and will prevent the issue in the future (except slow
    warning issues)
    4. Validate the test case
    5. Create a PR that references this original issue and add a link here to the new PR.
    6. If applicable record a demo of this feature using computer use and push the video to the new PR.

    When you open the PR, add the `cursor-waiting` label to it.
    """
  end

  defp advance_waiting(owner, repo, n) do
    num = to_string(n)

    case last_issue_comment_at(owner, repo, n) do
      nil ->
        log("cursor-waiting ##{num}: no timeline comments yet — posting @gemini review this PR")
        gh!(["pr", "comment", num, "--body", "@gemini review this PR"])

      ts ->
        age = DateTime.diff(DateTime.utc_now(), ts, :second)

        cond do
          age < @wait_seconds ->
            log(
              "cursor-waiting ##{num}: skip — last timeline comment #{age}s ago (need ≥#{@wait_seconds}s); last_comment_at=#{DateTime.to_iso8601(ts)}"
            )

          true ->
            log(
              "cursor-waiting ##{num}: gate passed (#{age}s since last timeline comment); advancing (last_comment_at=#{DateTime.to_iso8601(ts)})"
            )

            log("cursor-waiting ##{num}: action remove-label cursor-waiting")
            gh!(["pr", "edit", num, "--remove-label", "cursor-waiting"])
            log("cursor-waiting ##{num}: action pr comment (@cursor /branch-code-review)")

            gh!([
              "pr",
              "comment",
              num,
              "--body",
              "@cursor /branch-code-review and fix the issues found"
            ])

            log("cursor-waiting ##{num}: action add-label cursor-waiting-for-ci")
            gh!(["pr", "edit", num, "--add-label", "cursor-waiting-for-ci"])
            log("cursor-waiting ##{num}: transition complete → cursor-waiting-for-ci")
        end
    end
  end

  defp advance_waiting_for_ci(owner, repo, n) do
    num = to_string(n)
    head_oid = pr_head_oid(num)

    checks =
      gh!(["pr", "checks", num, "--json", "name,state,bucket,link,workflow"]) |> Jason.decode!()

    cond do
      checks == [] ->
        log("cursor-waiting-for-ci ##{num}: skip — no checks reported by gh")

      Enum.any?(checks, &(&1["bucket"] == "pending")) ->
        names =
          checks |> Enum.filter(&(&1["bucket"] == "pending")) |> Enum.map_join(", ", & &1["name"])

        log("cursor-waiting-for-ci ##{num}: skip — CI still pending (#{names})")

      true ->
        failed = Enum.filter(checks, &(&1["bucket"] == "fail"))
        cancelled = Enum.filter(checks, &(&1["bucket"] == "cancel"))

        cond do
          failed != [] ->
            maybe_post_ci_fix(owner, repo, num, head_oid, failed, &ci_fix_comment/2,
              dup:
                "CI still failing on same head #{short_oid(head_oid)}… — skip duplicate @cursor CI prompt",
              post: "CI failed — posting @cursor prompt"
            )

          cancelled != [] ->
            maybe_post_ci_fix(owner, repo, num, head_oid, cancelled, &ci_cancel_comment/2,
              dup:
                "CI still shows cancelled runs on same head #{short_oid(head_oid)}… — skip duplicate @cursor cancelled-CI prompt",
              post: "CI cancelled — posting @cursor prompt"
            )

          Enum.all?(checks, &(&1["bucket"] in ["pass", "skipping"])) ->
            log("cursor-waiting-for-ci ##{num}: all checks green/skipped — moving to cursor-demo")
            log("cursor-waiting-for-ci ##{num}: action remove-label cursor-waiting-for-ci")
            gh!(["pr", "edit", num, "--remove-label", "cursor-waiting-for-ci"])
            log("cursor-waiting-for-ci ##{num}: action add-label cursor-demo")
            gh!(["pr", "edit", num, "--add-label", "cursor-demo"])
            log("cursor-waiting-for-ci ##{num}: transition complete → cursor-demo")

          true ->
            bad =
              checks
              |> Enum.reject(&(&1["bucket"] in ["pass", "fail", "pending", "skipping", "cancel"]))
              |> Enum.map_join(", ", & &1["bucket"])

            log(
              "cursor-waiting-for-ci ##{num}: skip — unexpected check buckets (#{bad}); needs manual review"
            )
        end
    end
  end

  defp short_oid(oid), do: String.slice(oid, 0, 7)

  defp maybe_post_ci_fix(owner, repo, num, head_oid, items, body_fun, opts) do
    prompted_for =
      fetch_all_issue_comments(owner, repo, num)
      |> latest_marker_head_oid(@ci_fix_marker)

    cond do
      prompted_for == head_oid ->
        log("cursor-waiting-for-ci ##{num}: #{opts[:dup]}")

      true ->
        log(
          "cursor-waiting-for-ci ##{num}: #{opts[:post]} (head #{short_oid(head_oid)}…, last prompt was #{format_optional_oid(prompted_for)})"
        )

        gh!(["pr", "comment", num, "--body", body_fun.(head_oid, items)])
    end
  end

  defp advance_demo(owner, repo, n) do
    num = to_string(n)
    head_oid = pr_head_oid(num)
    comments = fetch_all_issue_comments(owner, repo, num)
    prompted_for = latest_marker_head_oid(comments, @demo_marker)

    cond do
      prompted_for == head_oid ->
        log(
          "cursor-demo ##{num}: demo prompt already posted for head #{short_oid(head_oid)}… — skip duplicate comment"
        )

      true ->
        log(
          "cursor-demo ##{num}: posting @cursor demo/screenshots prompt (head #{short_oid(head_oid)}…)"
        )

        gh!(["pr", "comment", num, "--body", demo_comment(head_oid)])
    end

    log("cursor-demo ##{num}: action remove-label cursor-demo")
    gh!(["pr", "edit", num, "--remove-label", "cursor-demo"])
    log("cursor-demo ##{num}: action add-label cursor-waiting-for-human")
    gh!(["pr", "edit", num, "--add-label", "cursor-waiting-for-human"])
    log("cursor-demo ##{num}: transition complete → cursor-waiting-for-human")
  end

  defp format_optional_oid(nil), do: "none"
  defp format_optional_oid(oid), do: short_oid(oid) <> "…"

  defp check_lines(items) do
    Enum.map_join(items, "\n", fn c -> "- **#{c["name"]}** — `#{c["state"]}` — #{c["link"]}" end)
  end

  defp ci_fix_comment(head_oid, failed) do
    """
    @cursor GitHub Actions failed on commit `#{head_oid}` (current PR head). Fix the failing jobs, push, and let CI re-run. This PR stays labeled `cursor-waiting-for-ci` until CI is green.

    Failed checks:
    #{check_lines(failed)}

    <!-- cursor-workflow:ci-fix head=#{head_oid} -->
    """
  end

  defp ci_cancel_comment(head_oid, cancelled) do
    """
    @cursor **Cancelled CI runs** on commit `#{head_oid}` (current PR head). This PR stays labeled `cursor-waiting-for-ci` until CI is green.

    **Cancelled checks (review these runs first):**
    #{check_lines(cancelled)}

    If a run was cancelled or stopped because of a failure or timeout caused by this PR, follow the logs for the run(s) above, fix the issue, and push. If you believe this was a flake, an accidental cancellation, or infra noise, re-run the workflow from the Actions UI (or restart the job) instead of changing code.

    <!-- cursor-workflow:ci-fix head=#{head_oid} -->
    """
  end

  defp demo_comment(head_oid) do
    """
    @cursor Check if there are already demo screenshots in this PR description and if not use computer use to use the feature and take screenshots of the feature / change. E.g. ensure to screenshot the changed/new parts in the ui flow not just any step in the computer use session. Then update the PR description and attach the screenshots to the description - Do not add the screenshots to the branch.

    <!-- cursor-workflow:demo head=#{head_oid} -->
    """
  end

  defp sort_comments_desc(comments) do
    comments
    |> Enum.reject(&is_nil(&1["created_at"]))
    |> Enum.sort(fn a, b ->
      DateTime.compare(
        parse_github_iso8601(a["created_at"]),
        parse_github_iso8601(b["created_at"])
      ) == :gt
    end)
  end

  defp latest_marker_head_oid(comments, regex) do
    comments
    |> sort_comments_desc()
    |> Enum.find_value(fn c ->
      case Regex.run(regex, c["body"] || "") do
        [_, oid] -> oid
        _ -> nil
      end
    end)
  end

  defp pr_head_oid(num) do
    gh!(["pr", "view", num, "--json", "headRefOid"])
    |> Jason.decode!()
    |> Map.fetch!("headRefOid")
  end

  defp last_issue_comment_at(owner, repo, issue_num) do
    fetch_all_issue_comments(owner, repo, issue_num)
    |> Enum.map(& &1["created_at"])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&parse_github_iso8601/1)
    |> max_datetime()
  end

  defp max_datetime([]), do: nil

  defp max_datetime([h | t]),
    do: Enum.reduce(t, h, fn d, acc -> if DateTime.compare(d, acc) == :gt, do: d, else: acc end)

  defp fetch_all_issue_comments(owner, repo, issue_num, page \\ 1, acc \\ []) do
    path = "repos/#{owner}/#{repo}/issues/#{issue_num}/comments?per_page=100&page=#{page}"
    batch = gh!(["api", path]) |> Jason.decode!()

    cond do
      batch == [] -> acc
      length(batch) < 100 -> acc ++ batch
      true -> fetch_all_issue_comments(owner, repo, issue_num, page + 1, acc ++ batch)
    end
  end

  defp parse_github_iso8601(str) do
    {:ok, dt, _} = DateTime.from_iso8601(str)
    dt
  end

  defp retryable_github_server_error?(output), do: output =~ ~r/status code: 5\d\d\b/

  defp gh!(args), do: gh!(args, @gh_retry_max_attempts, true)

  defp gh!(args, attempts_left, label_bootstrap) do
    case System.cmd("gh", args, stderr_to_stdout: true) do
      {out, 0} ->
        out

      {out, code} ->
        cond do
          attempts_left > 1 && label_bootstrap && label_assign_not_found?(out, args) ->
            case create_labels() do
              created when created > 0 ->
                log(
                  "gh label assign failed (exit #{code}), created #{created} repo label(s); retrying: #{Enum.join(args, " ")}"
                )

                gh!(args, attempts_left - 1, label_bootstrap)

              _ ->
                gh_halt!(args, code, out)
            end

          attempts_left > 1 && retryable_github_server_error?(out) ->
            nth = @gh_retry_max_attempts - attempts_left
            delay_ms = min(16_000, 2_000 * Integer.pow(2, nth))

            log(
              "gh HTTP 5xx (exit #{code}), retrying in #{delay_ms}ms (#{attempts_left - 1} attempt(s) left): #{Enum.join(args, " ")}"
            )

            Process.sleep(delay_ms)
            gh!(args, attempts_left - 1, label_bootstrap)

          true ->
            gh_halt!(args, code, out)
        end
    end
  end

  defp label_assign_not_found?(output, args) do
    "--add-label" in args &&
      case Regex.run(@label_not_found, output) do
        [_, name] -> name in workflow_label_names()
        _ -> false
      end
  end

  defp gh_halt!(args, code, out) do
    IO.puts(
      :stderr,
      "[#{iso_timestamp_now()}] gh failed (#{code}): #{inspect(Enum.join(args, " "))}"
    )

    IO.puts(:stderr, out)
    System.halt(1)
  end
end

IssueWorkflow.run()
