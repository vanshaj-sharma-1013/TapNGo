// Rules for the two names a player has: a short username (always set, shown on the
// leaderboard) and an optional full name. Lengths count characters, like Godot does.
export const NAME_MIN = 3;
export const NAME_MAX = 16;
export const FULL_NAME_MAX = 40;

const USERNAME_PATTERN = /^[\p{L}\p{N}_. -]+$/u;
const FULL_NAME_PATTERN = /^[\p{L}\p{M}' .-]+$/u;

// Offensive-name filter. Text is lowercased, optionally de-leetspoken (f4ck, sh1t), stripped
// to letters and shrunk so repeated letters count once (fuuuck), which also defeats dots
// and spaces between letters (f.u.c.k).
const LEET: Record<string, string> = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i" };

function squash(value: string, leet: boolean): string {
  const text = [...value.toLowerCase()].map((c) => (leet ? LEET[c] ?? c : c)).join("");
  return text.replace(/[^\p{L}]/gu, "").replace(/(.)\1+/gu, "$1");
}

// Blocked wherever they appear inside the name. Only long, unambiguous words go here,
// because short ones would block innocent names ("class" contains "ass").
const BLOCKED_ANYWHERE = [
  "fuck", "shit", "bitch", "cunt", "nigger", "nigga", "faggot", "whore", "slut", "dildo",
  "pussy", "asshole", "bastard", "wanker", "retard", "rapist", "blowjob", "jizz", "cocksucker",
].map((word) => squash(word, false));

// Blocked only as a whole word ("ass", "sex_god") so names like "Classic" or "Nazir" pass.
const BLOCKED_WORDS = new Set([
  "ass", "arse", "dick", "cock", "piss", "tit", "tits", "boob", "boobs", "sex", "sexy", "porn",
  "rape", "nazi", "hitler", "anal", "anus", "penis", "vagina", "cum", "milf", "hoe", "fag",
].map((word) => squash(word, false)));

// True if the name looks offensive.
export function isOffensive(value: string): boolean {
  for (const leet of [true, false]) {
    if (BLOCKED_ANYWHERE.some((word) => squash(value, leet).includes(word))) {
      return true;
    }
    const words = value.split(/[\s._-]+/u).map((word) => squash(word, leet));
    if (words.some((word) => BLOCKED_WORDS.has(word))) {
      return true;
    }
  }
  return false;
}

function tidy(value: unknown): string | null {
  return typeof value === "string" ? value.normalize("NFC").replace(/\s+/g, " ").trim() : null;
}

// Returns the cleaned username, or null if it isn't allowed.
export function cleanUsername(value: unknown): string | null {
  const name = tidy(value);
  if (name === null) {
    return null;
  }
  const length = [...name].length;
  return length >= NAME_MIN && length <= NAME_MAX && USERNAME_PATTERN.test(name) ? name : null;
}

// Returns the cleaned full name ("" is fine, it is optional), or null if it isn't allowed.
export function cleanFullName(value: unknown): string | null {
  const name = tidy(value ?? "");
  if (name === null || [...name].length > FULL_NAME_MAX) {
    return null;
  }
  return name === "" || FULL_NAME_PATTERN.test(name) ? name : null;
}
