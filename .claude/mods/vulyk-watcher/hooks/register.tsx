import type { Register } from 'claude-code'

export const register: Register = on => {
  on('turn.complete', async ($, e, next) => next(e))
}
