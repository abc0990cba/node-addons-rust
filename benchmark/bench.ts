import { Bench } from 'tinybench'

import { fibonacci } from '../index.js'

function fib(n: number): number {
  return n <= 1 ? n : fib(n - 1) + fib(n - 2);
}

const b = new Bench();

const N = 40;

b.add(`Native fibonacci for ${N}`, () => {
  fibonacci(N)
})

b.add(`JavaScript fibonacci for ${N}`, () => {
  fib(N)
})

await b.run()

console.table(b.table())
