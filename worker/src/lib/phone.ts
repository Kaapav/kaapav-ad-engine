export function normalizePhone10(input: string | null | undefined): string | null {
  const d = String(input ?? '').replace(/\D/g, '');

  if (d.length === 10) return d;
  if (d.length === 12 && d.startsWith('91')) return d.slice(2);
  if (d.length === 11 && d.startsWith('0')) return d.slice(1);

  return null;
}