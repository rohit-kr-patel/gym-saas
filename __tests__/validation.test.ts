import { signInSchema } from '@/lib/validation';

describe('signInSchema', () => {
  it('accepts valid credentials', () => {
    expect(signInSchema.safeParse({ email: 'a@b.co', password: 'longenough' }).success).toBe(true);
  });
  it('rejects bad email and short password', () => {
    expect(signInSchema.safeParse({ email: 'nope', password: 'longenough' }).success).toBe(false);
    expect(signInSchema.safeParse({ email: 'a@b.co', password: 'short' }).success).toBe(false);
  });
});
