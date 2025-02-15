import test from 'ava'

import { fibonacci } from '../index'

test('sync function from native code', (t) => {
  const fixture = 100
  t.is(fibonacci(fixture), 354224848179261915075)
})
