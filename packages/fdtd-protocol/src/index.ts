import { z } from 'zod'

export const SimTypeSchema = z.enum(['1D', '2D', '2D_TFSF'])
export type SimType = z.infer<typeof SimTypeSchema>

export const WsEventSchema = z.enum(['start', 'pause', 'continue', 'close'])
export type WsEvent = z.infer<typeof WsEventSchema>

export const FrameFormatSchema = z.enum(['binary', 'json'])
export type FrameFormat = z.infer<typeof FrameFormatSchema>

export const MaterialSchema = z.object({
  id: z.number().int().nonnegative(),
  eps: z.number().positive(),
  mu: z.number().positive(),
  sigma: z.number().nonnegative(),
})
export type Material = z.infer<typeof MaterialSchema>

export const ControlMessageSchema = z.object({
  event: WsEventSchema,
  type: SimTypeSchema.optional(),
  /** 0=Hz, 1=Ex, 2=Ey, 3=Energy (normalized; legacy misnamed Ez→Hz). */
  dataToReturn: z.number().int().nonnegative().optional(),
  /** 1D: [omega, tau]; 2D: [lambda, beamsize]. */
  condition: z.tuple([z.number(), z.number()]).optional(),
  materialMatrix: z.array(z.array(z.number().int())).optional(),
  materials: z.array(MaterialSchema).optional(),
  srcPositionRelative: z
    .array(z.object({ x: z.number(), y: z.number() }))
    .optional(),
  srcType: z.number().int().optional(),
  /** Default `binary`. Use `json` for /docs debugging. */
  frameFormat: FrameFormatSchema.optional(),
})
export type ControlMessage = z.infer<typeof ControlMessageSchema>

export const StepAckSchema = z.object({
  step: z.number().int().nonnegative(),
})
export type StepAck = z.infer<typeof StepAckSchema>

export const ClientMessageSchema = z.union([ControlMessageSchema, StepAckSchema])
export type ClientMessage = z.infer<typeof ClientMessageSchema>

/** JSON frame (fallback / debugging). */
export const Frame1DSchema = z.object({
  kind: z.literal('1d').optional(),
  dataX: z.array(z.number()),
  dataY: z.array(z.number()),
  step: z.number().int(),
  col: z.number().int(),
  max: z.number().optional(),
  min: z.number().optional(),
})
export type Frame1D = z.infer<typeof Frame1DSchema>

export const Frame2DSchema = z.object({
  kind: z.literal('2d').optional(),
  dataX: z.array(z.number()),
  dataY: z.array(z.number()),
  dataVal: z.array(z.number()),
  step: z.number().int(),
  row: z.number().int(),
  col: z.number().int(),
  max: z.number(),
  min: z.number(),
  hz: z.array(z.number()).optional(),
  ex: z.array(z.number()).optional(),
  ey: z.array(z.number()).optional(),
})
export type Frame2D = z.infer<typeof Frame2DSchema>

export type SimFrame = Frame1D | Frame2D

export {
  BINARY_FRAME_MAGIC,
  BINARY_FRAME_VERSION,
  BinaryKind,
  decodeBinaryFrame,
  encodeBinaryFrame,
  isBinaryFrame,
  type BinaryKindCode,
  type DecodedBinaryFrame,
  type EncodeBinaryInput,
} from './binary.js'
