{-| @Runtime.Shade — per-pixel lighting for the raster driver

    Lambert diffuse above an ambient floor, a Blinn-Phong highlight and a
    Schlick Fresnel blend toward a procedural sky reflected about the normal.
    Everything is linear light; the driver quantizes afterwards. -}
module Pudu.Runtime.Shade
  ( Lighting
  , lighting
  , shade
  , uniformCount
  ) where

import Pudu.Runtime.Lanes (Lanes, laneCount, laneToList)

{-| Camera position, unit direction toward the light, light color, ambient
    floor, specular exponent and strength, Fresnel reflectance at normal
    incidence, sky horizon and zenith colors and the cosine of the sun's
    angular radius. -}
data Lighting = Lighting
  !Double !Double !Double
  !Double !Double !Double
  !Double !Double !Double
  !Double !Double !Double !Double
  !Double !Double !Double
  !Double !Double !Double
  !Double

{-| Values in a uniform lane, in the order 'lighting' reads them. -}
uniformCount :: Int
uniformCount = 20

{-| Uniforms from a lane: camera xyz, light direction xyz, light rgb, ambient,
    exponent, strength, f0, horizon rgb, zenith rgb, sun cosine. Nothing unless
    every value is finite, the light direction has length, ambient and f0 lie
    in [0, 1], the exponent is positive and the sun cosine lies in (0, 1). -}
lighting :: Lanes -> Maybe Lighting
lighting lane
  | laneCount lane /= uniformCount = Nothing
  | otherwise = case laneToList lane of
      [cx, cy, cz, lx, ly, lz, lr, lg, lb, ambient, power, strength, f0, hr, hg, hb, zr, zg, zb, sun]
        | any (\v -> isNaN v || isInfinite v) values -> Nothing
        | size <= 0 -> Nothing
        | ambient < 0 || ambient > 1 || f0 < 0 || f0 > 1 -> Nothing
        | power <= 0 || strength < 0 || sun <= 0 || sun >= 1 -> Nothing
        | otherwise ->
            Just (Lighting cx cy cz (lx / size) (ly / size) (lz / size) lr lg lb ambient power strength f0 hr hg hb zr zg zb sun)
        where
          values = [cx, cy, cz, lx, ly, lz, lr, lg, lb, ambient, power, strength, f0, hr, hg, hb, zr, zg, zb, sun]
          size = sqrt (lx * lx + ly * ly + lz * lz)
      _ -> Nothing

{-| Shade one pixel from its interpolated normal, world position and base
    color. The normal faces the camera, so either side of a surface lights. -}
shade :: Lighting -> Double -> Double -> Double -> Double -> Double -> Double -> Double -> Double -> Double -> (Double, Double, Double)
shade (Lighting cx cy cz lx ly lz lr lg lb ambient power strength f0 hr hg hb zr zg zb sun) nx0 ny0 nz0 px py pz r g b
  | normalLength <= 0 || viewLength <= 0 = (r * ambient, g * ambient, b * ambient)
  | otherwise = (channel r lr hr zr, channel g lg hg zg, channel b lb hb zb)
  where
    normalLength = sqrt (nx0 * nx0 + ny0 * ny0 + nz0 * nz0)
    vx0 = cx - px
    vy0 = cy - py
    vz0 = cz - pz
    viewLength = sqrt (vx0 * vx0 + vy0 * vy0 + vz0 * vz0)
    vx = vx0 / viewLength
    vy = vy0 / viewLength
    vz = vz0 / viewLength
    facing = (nx0 * vx + ny0 * vy + nz0 * vz) / normalLength
    side = if facing < 0 then -1 / normalLength else 1 / normalLength
    nx = nx0 * side
    ny = ny0 * side
    nz = nz0 * side
    nv = max 0 (nx * vx + ny * vy + nz * vz)
    diffuse = ambient + (1 - ambient) * max 0 (nx * lx + ny * ly + nz * lz)
    hx0 = lx + vx
    hy0 = ly + vy
    hz0 = lz + vz
    halfLength = sqrt (hx0 * hx0 + hy0 * hy0 + hz0 * hz0)
    highlight
      | halfLength <= 0 = 0
      | otherwise = strength * max 0 ((nx * hx0 + ny * hy0 + nz * hz0) / halfLength) ** power
    fresnel = f0 + (1 - f0) * (1 - nv) ^ (5 :: Int)
    -- The view direction mirrored about the normal, as the reflected ray.
    rx = 2 * nv * nx - vx
    ry = 2 * nv * ny - vy
    rz = 2 * nv * nz - vz
    up = sqrt (max 0 (min 1 ry))
    toward = rx * lx + ry * ly + rz * lz
    disc
      | toward <= sun = 0
      | otherwise = min 1 ((toward - sun) / (1 - sun) * 4)
    channel base light horizon zenith =
      let sky = horizon + (zenith - horizon) * up + light * disc
       in base * diffuse * (1 - fresnel) + sky * fresnel + light * highlight
