#!/bin/bash
# visual-verify-guard.sh — Stop hook that warns if frontend files were changed
# but visual verification was not mentioned in the conversation output.
# This is an advisory hook (exits 0) that adds a reminder message.

# Check if any staged or unstaged frontend files were modified
FRONTEND_CHANGES=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(tsx|jsx|css|html|vue|svelte)$' | head -5)

if [ -z "$FRONTEND_CHANGES" ]; then
  # Also check unstaged changes
  FRONTEND_CHANGES=$(git diff --name-only 2>/dev/null | grep -E '\.(tsx|jsx|css|html|vue|svelte)$' | head -5)
fi

if [ -n "$FRONTEND_CHANGES" ]; then
  echo "VISUAL VERIFICATION REMINDER: Frontend files were modified. Ensure the 3-tool visual pipeline ran: /visual-verify + /visual-regression + visual-tester agent. Modified: $(echo $FRONTEND_CHANGES | tr '\n' ', ')"
fi

exit 0
