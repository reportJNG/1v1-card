-- Type definitions for TestEZ globals, used by luau-lsp when checking tests/.
declare function describe(phrase: string, callback: () -> ()): ()
declare function it(phrase: string, callback: () -> ()): ()
declare function itSKIP(phrase: string, callback: () -> ()): ()
declare function itFOCUS(phrase: string, callback: () -> ()): ()
declare function beforeEach(callback: () -> ()): ()
declare function afterEach(callback: () -> ()): ()
declare function beforeAll(callback: () -> ()): ()
declare function afterAll(callback: () -> ()): ()
declare function expect(value: any): any
