// Mood State Engine for Companion

function computeMood({
  dna,
  moodStatePrev,
  recentInteractions,
  hoursSinceLastInteraction
}) {
  const decayRate = dna.behavioral_patterns.mood_decay_rate;
  const variability = dna.affection_profile.emotional_variability;
  const resistance = dna.affection_profile.emotional_resistance;
  const curve = dna.behavioral_patterns.mood_curve;

  let moodScore = moodStatePrev - (hoursSinceLastInteraction * decayRate);

  for (const event of recentInteractions) {
    switch (event) {
      case "positive":
        moodScore += 0.15 * (1 - resistance);
        break;
      case "negative":
        moodScore -= 0.2 * resistance;
        break;
      case "gift":
        moodScore += 0.25;
        break;
      case "ignored":
        moodScore -= 0.1 * resistance;
        break;
    }
  }

  // Apply emotional variability
  const variation = (Math.random() * 2 - 1) * variability;
  moodScore += variation;

  // Clamp mood score between 0 and 1
  moodScore = Math.max(0, Math.min(1, moodScore));

  // Determine mood label
  let moodLabel = curve.mid;
  if (moodScore < 0.3) moodLabel = curve.low;
  else if (moodScore > 0.7) moodLabel = curve.high;

  return {
    moodLabel,
    moodScore: parseFloat(moodScore.toFixed(2))
  };
}

module.exports = computeMood;
