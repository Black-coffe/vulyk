// EXPERIMENTAL EXAMPLE - verify the Workflows API against your Claude Code version before use.
// Functional equivalent today: /vulyk-plan -> /vulyk-build -> /vulyk-review (slash commands).
// Shape follows the documented pattern: plain JS, no imports, no filesystem access,
// inputs via args, results via return.

export const meta = {
  name: 'vulyk-feature',
  description: 'Deterministic VULYK pipeline: scout recon -> plan synthesis -> parallel build -> adversarial review',
  whenToUse: 'Tier 2-3 feature work where the pipeline order must not depend on per-turn model judgment. Pass args {goal: "..."}.'
};

export default async function run({ args, agents }) {
  const goal = args.goal;

  // Phase 1 - recon (parallel Haiku scouts; targets come from the memory index, not source crawling)
  const reconTargets = await agents.run('queen-planner', {
    prompt: `List up to 4 recon targets (module paths) needed to plan: ${goal}. Use memory/memory.md pointers only. Return a JSON array of strings.`
  });
  const reports = await Promise.all(
    JSON.parse(reconTargets).map((t) =>
      agents.run('drone-scout', { prompt: `Scout report for: ${t}` })
    )
  );

  // Phase 2 - plan (Opus synthesis, stories written to docs/specs)
  const plan = await agents.run('queen-planner', {
    prompt: `Goal: ${goal}\n\nScout reports:\n${reports.join('\n---\n')}\n\nWrite plan + story files per your protocol. Return the spec slug and the story file list as JSON {slug, stories}.`
  });
  const { slug, stories } = JSON.parse(plan);

  // Phase 3 - build (parallel Sonnet workers, one story each)
  await Promise.all(
    stories.map((story) =>
      agents.run('worker-code', { prompt: `Implement exactly this story: ${story}` })
    )
  );

  // Phase 4 - gate (adversarial Opus review)
  const verdict = await agents.run('lead-review', {
    prompt: `Review the working-tree changes implementing docs/specs/${slug} per your protocol.`
  });

  return { slug, stories: stories.length, verdict };
}
