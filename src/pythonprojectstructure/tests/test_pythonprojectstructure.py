"""
project-structure unit and integration tests.
"""

import sys
import subprocess  # nosec B404

import unittest


class ProjectstructureTests(unittest.TestCase):
    """
    project-structure unit and integration tests.
    """

    def test_importable(self):
        """
        The Python package is on `sys.path` and thus importable.
        """
        import_process = subprocess.run(  # nosec B603
            [sys.executable, "-c", "import projectstructure"],
            check=True,
        )
        self.assertEqual(
            import_process.returncode,
            0,
            "The Python package not importable",
        )
