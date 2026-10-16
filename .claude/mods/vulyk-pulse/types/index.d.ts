// The pulse mod's $.state contract (plugin.json "types"): what survives a hot reload.

export type PulseTask = { start: number; last: number; open: boolean; idle?: number }
export type PulseAgent = { type: string; live: boolean }
export type PulsePlace = { wave: number; round: number }

declare module 'claude-code' {
  interface PluginState {
    'vulyk-pulse': {
      task: PulseTask | null
      tally: number
      agents: Record<string, PulseAgent>
      spec: string
      place: PulsePlace
    }
  }
}
