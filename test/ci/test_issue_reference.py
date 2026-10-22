"""Exercise the actual issue-reference shell step from the public CI workflow."""

import os
from pathlib import Path
import subprocess
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[2] / ".github/workflows/ci.yml"


def validation_command():
    step = WORKFLOW.read_text().split("- name: Validar issue vinculada en el PR\n", 1)[1]
    block = step.split("        run: |\n", 1)[1].split("\n\n", 1)[0]
    return textwrap.dedent(block)


class IssueReferenceTest(unittest.TestCase):
    def assert_result(self, body, code, stdout):
        result = subprocess.run(
            ["bash", "-c", validation_command()],
            env={**os.environ, "BODY": body},
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, code, (result.stdout, result.stderr))
        self.assertEqual(result.stdout, stdout)
        self.assertEqual(result.stderr, "")

    def test_accepts_nonclosing_reference_for_partial_stacked_pr(self):
        self.assert_result("## Issue vinculada\n\nRefs #303\n", 0, "")

    def test_preserves_existing_closing_references(self):
        for verb in ("Closes", "Fixes", "Resolves"):
            with self.subTest(verb=verb):
                self.assert_result(f"## Issue vinculada\n\n{verb} #303\n", 0, "")

    def test_rejects_missing_or_malformed_issue_reference(self):
        message = "Error: Vincular issue (ej. 'Closes #1' o 'Refs #1' para PRs parciales).\n"
        for body in (
            "", "Cambio sin issue", "Refs #", "Refs #abc", "Refs 303",
            "Refs #303abc", "prefixRefs #303",
        ):
            with self.subTest(body=body):
                self.assert_result(body, 1, message)


if __name__ == "__main__":
    unittest.main()
