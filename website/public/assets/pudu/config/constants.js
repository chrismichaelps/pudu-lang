// The drawing's own units: its view box is 200 by 150 and the banner's top
// edge crosses it at REST_LINE.
export const VIEW_WIDTH = 200;
export const VIEW_HEIGHT = 150;
export const REST_LINE = 130;

// How far the body sits below its resting pose, in drawing units.
export const POSE = {
  up: 0,
  eyes: 34,
  hidden: 92,
};

// How far the face slides at a full look, and how far the head tilts.
export const FACE_TURN = 6;
export const LOOK_TILT = 4;
export const CURIOUS_TILT = 11;
export const ASK_TILT = 8;

// Ear rotations, in degrees, for the left ear; the right ear mirrors them.
export const EAR = {
  flick: 16,
  droop: -24,
  perk: 10,
};

export const EYE_WIDE = 1.14;

// Pixels kept between the pudu and the banner's rounded corners.
export const EDGE_CLEARANCE = 36;

// A new spot lands at least this share of the edge away from the last one.
export const SPOT_SPREAD = 0.3;
export const SPOT_TRIES = 8;

export const TIMING = {
  rise: 640,
  riseSlow: 1100,
  duck: 360,
  duckFast: 200,
  sink: 460,
  look: 380,
  follow: 200,
  blink: 150,
  flick: 260,
  sniff: 420,
  hop: 460,
  heart: 1300,
  grip: 220,
  letGo: 130,
  marks: 560,
  nod: 1100,
};

// The share of a rise after which the hooves reach over the edge.
export const GRIP_AT = 0.55;

export const ROAM = {
  firstEntrance: 1200,
  hiddenMin: 1600,
  hiddenMax: 4200,
  holdMin: 520,
  holdMax: 1150,
  beatsMin: 2,
  beatsMax: 4,
  doubleTake: 0.22,
};

export const SHY = {
  startleRadius: 150,
  calmRadius: 240,
  calmFor: 600,
  idleBeforeSearch: 3600,
  tick: 200,
  lookReach: 260,
  awayMin: 900,
  awayMax: 1500,
};

export const ASK = {
  firstEntrance: 700,
  gestureMin: 2800,
  gestureMax: 5200,
  hold: 900,
  spotShare: 0.72,
};

export const BLINK = {
  min: 2200,
  max: 5200,
  twice: 0.22,
};

export const EASE = {
  out: "cubic-bezier(.22,.9,.3,1)",
  in: "cubic-bezier(.5,0,.8,.3)",
  inOut: "cubic-bezier(.45,.05,.4,1)",
  spring: "cubic-bezier(.3,1.5,.5,1)",
};

export const SELECTOR = {
  stage: "[data-pudu]",
  frontClass: "pudu-stage pudu-stage-front",
  host: ".pudu-host",
};

export const REDUCED_MOTION = "(prefers-reduced-motion: reduce)";
