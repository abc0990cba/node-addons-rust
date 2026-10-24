/** Domain materials — matches legacy client defaults (enriched). */
export type UiMaterial = {
  id: number
  name: string
  color: string
  eps: number
  mu: number
  sigma: number
}

export const DEFAULT_MATERIALS: UiMaterial[] = [
  {
    id: 0,
    name: 'Free space',
    color: '#2a3544',
    eps: 1,
    mu: 1,
    sigma: 0,
  },
  {
    id: 1,
    name: 'Dielectric',
    color: '#e07060',
    eps: 2.3,
    mu: 1,
    sigma: 0,
  },
  {
    id: 2,
    name: 'Lossy / metal-like',
    color: '#3a6db0',
    eps: 40.6,
    mu: 1,
    sigma: 0.02,
  },
]

export function toWireMaterials(materials: UiMaterial[]) {
  return materials.map(({ id, eps, mu, sigma }) => ({ id, eps, mu, sigma }))
}
