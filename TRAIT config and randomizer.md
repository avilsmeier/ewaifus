// Trait Configuration and Randomizer

const crypto = require('crypto');

const TRAITS = {
  "gender_identity": ["feminine", "masculine", "androgynous", "fluid", "neutral"],
  "presentation": ["elegant", "cute", "mysterious", "playful", "active", "fit", "obese", "curvy", "hippie", "rugged", "pin up", "gangster", "street", "vintage", "gothic", "punk", "formal"],
  "species": ["human", "elf", "kitsune", "cyber", "lycan", "fox", "vampire", "alien", "ethereal", "interdimensional", "dryad", "construct", "android"],
  "temperament": ["shy", "bold", "loyal", "curious", "chivalrous", "bipolar", "flirty", "serious", "playful", "caring", "nurturing", "strong", "sexy", "stoic", "eccentric"],
  "personality_core": ["INFJ", "ENFP", "ISTP", "INTJ", "ESFJ", "ISFP", "ENTP", "ESTJ"],
  "emotional_depth": [0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
  "hair_color": ["silver", "black", "pink", "blonde", "blue", "red", "brown", "honey", "white", "purple", "green", "orange", "multicolor"],
  "hair_type": ["straight", "wavy", "curly", "groomed", "wild", "braided"],
  "eye_color": ["emerald", "violet", "gold", "crimson", "black", "green", "blue", "brown", "hazel", "purple", "yellow", "gray", "silver", "amber"],
  "skin_tone": ["pale", "olive", "tan", "brown", "ebony", "porcelain"],
  "ethnicity": ["european", "asian", "african", "mixed", "latino", "hindi", "native", "arab", "slavic"],
  "body_type": ["slim", "athletic", "soft", "chubby", "hourglass", "muscular"],
  "face_shape": ["heart", "oval", "round", "sharp", "square", "diamond"],
  "height_cm": [140, 145, 150, 155, 160, 165, 170, 175, 180],
  "language": ["english", "japanese", "french", "spanish", "portuguese", "chinese", "german", "korean", "italian", "russian"],
  "nationality": ["japanese", "italian", "greek", "korean", "argentinian", "american", "peruvian", "chilean", "british", "german", "chinese", "brazilian", "russian", "ukranian", "thai", "swedish"],
  "religion": ["shinto", "none", "spiritual", "animist", "christian", "buddhist", "jewish", "muslim", "taoist", "agnostic"],
  "political_orientation": ["neutral", "progressive", "traditional", "liberal", "democrat", "republican", "communist", "socialist", "libertarian"],
  "hobby": ["calligraphy", "gardening", "alchemy", "gaming", "painting", "karting", "horse riding", "biking", "sailing", "woodworking", "knitting", "fencing", "poetry", "dancing", "sculpting", "hacking"],
  "favorite_pet": ["fox", "cat", "dragon", "owl", "dog", "hamster", "turtle", "bird", "lizard", "spider", "snake", "duck", "cow", "pig", "rabbit", "ferret"],
  "outfit_theme": ["school uniform", "mystical robes", "battle armor", "casual hoodie", "cyberpunk gear", "forest attire", "traditional kimono", "space suit", "maid outfit", "sailor uniform"],
  "style": ["anime", "digital painting", "watercolor", "pixel art", "line art", "realistic", "cartoon"]
};

function getVoiceProfileConfig(dna) {
  return {
    language: dna.cultural_profile.language,
    gender: dna.gender_identity,
    pitch: dna.voice_profile?.pitch || 1.0,
    tone: dna.voice_profile?.tone || "neutral",
    pace: dna.voice_profile?.pace || "normal",
    accent: dna.cultural_profile.nationality,
    presentation: dna.presentation,
    temperament: dna.temperament
  };
}

function getVisualPrompt(dna) {
  const ap = dna.appearance;
  return `${dna.presentation} ${dna.gender_identity} ${dna.species} with ${ap.hair_type} ${ap.hair_color} hair, ${ap.eye_color} eyes, ${ap.skin_tone} skin, ${ap.face_shape}-shaped face, wearing ${dna.outfit_theme || 'a themed outfit'}, full body portrait, ${dna.style || 'anime style'}`;
}

function generateImmutableDNA(fullDNA) {
  const ap = fullDNA.appearance;
  return {
    species: fullDNA.species,
    skin_tone: ap.skin_tone,
    eye_color: ap.eye_color,
    face_shape: ap.face_shape,
    body_type: ap.body_type,
    birthday: fullDNA.birthday,
    personality_core: fullDNA.personality_core,
    style: fullDNA.style,
    height_cm: ap.height_cm,
    appearance_seed: ap.appearance_seed
  };
}

function generateMutableProfile(fullDNA) {
  return {
    gender_identity: fullDNA.gender_identity,
    presentation: fullDNA.presentation,
    temperament: fullDNA.temperament,
    cultural_profile: fullDNA.cultural_profile,
    hobby: fullDNA.hobby,
    favorite_pet: fullDNA.favorite_pet,
    outfit_theme: fullDNA.outfit_theme,
    voice_profile: fullDNA.voice_profile,
    hair_color: fullDNA.appearance.hair_color,
    hair_type: fullDNA.appearance.hair_type
  };
}

function hashDNA(dna) {
  const json = JSON.stringify(dna);
  return crypto.createHash('blake2b512').update(json).digest('hex');
}

function generateCIP68Metadata(dna, owner, ipfsCID) {
  return {
    version: "1.0",
    dna_hash: hashDNA(generateImmutableDNA(dna)),
    personality_ref: `ipfs://${ipfsCID}`,
    owner,
    minted_at: Date.now()
  };
}

module.exports = {
  TRAITS,
  getVoiceProfileConfig,
  getVisualPrompt,
  hashDNA,
  generateImmutableDNA,
  generateMutableProfile,
  generateCIP68Metadata
};
