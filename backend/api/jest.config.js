/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
  testMatch: ["**/*.test.ts"],
  transform: {
    "^.+\\.ts$": ["ts-jest", { tsconfig: "tsconfig.jest.json" }],
  },
  // Todos os arquivos de teste compartilham o mesmo emulador do Firestore
  // (mesmo projeto/banco) — rodar em paralelo faz um arquivo apagar dados
  // que outro acabou de criar. Serial evita essa corrida.
  maxWorkers: 1,
};
