# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

"""
Test the project-structure Command-Line Interface.
"""

import sys
import io
import runpy
import subprocess  # nosec B404
import contextlib
import pathlib

import unittest

import projectstructure


class ProjectstructureCLITests(unittest.TestCase):
    """
    Test the project-structure Command-Line Interface.
    """

    def test_importable(self):
        """
        The Python package is on `sys.path` and importable.
        """
        import_process = subprocess.run(  # nosec B603
            [sys.executable, "-c", "import projectstructure"],
            check=False,
        )
        self.assertEqual(
            import_process.returncode,
            0,
            "The Python package not importable",
        )

    def get_cli_error_messages(self, args):
        """
        Run the CLI script and return any error messages.
        """
        stderr_file = io.StringIO()
        with self.assertRaises(SystemExit, msg="CLI didn't exit"):
            with contextlib.redirect_stderr(stderr_file):
                projectstructure.main(args=args)
        return stderr_file.getvalue()

    def test_cli_help(self):
        """
        The command line script is self-docummenting.
        """
        stdout_file = io.StringIO()
        with self.assertRaises(SystemExit, msg="CLI didn't exit"):
            with contextlib.redirect_stdout(stdout_file):
                projectstructure.main(args=["--help"])
        stdout = stdout_file.getvalue()
        self.assertIn(
            projectstructure.__doc__.strip(),
            stdout.replace("\n", " "),
            "The console script name missing from --help output",
        )

    def test_cli_subcommand(self):
        """
        The command line supports sub-commands.
        """
        self.assertIsNone(
            projectstructure.main(args=["foobar"]),
            "Wrong console script sub-command return value",
        )

    def test_cli_options(self):
        """
        The command line script accepts options controlling behavior.
        """
        self.assertIsNone(
            projectstructure.main(args=["--log-level", "DEBUG", "foobar", "-q"]),
            "Wrong console script options return value",
        )

    def test_cli_option_errors(self):
        """
        The command line script displays useful messages for invalid option values.
        """
        stderr = self.get_cli_error_messages(args=["foobar", "--non-existent-option"])
        self.assertIn(
            "error: unrecognized arguments: --non-existent-option",
            stderr,
            "Wrong invalid option message",
        )

    def test_cli_dash_m_option(self):
        """
        The package supports execution via Python's `-m` CLI option.
        """
        module_main_process = subprocess.run(  # nosec B603
            [sys.executable, "-m", "projectstructure", "foobar"],
            check=False,
        )
        self.assertEqual(
            module_main_process.returncode,
            0,
            "Running via Python's `-m` option exited with non-zero status code",
        )

    def test_cli_module_main(self):
        """
        The package supports execution via Python's `-m` option.
        """
        with self.assertRaises(SystemExit, msg="CLI didn't exit") as exc_context:
            runpy.run_module("projectstructure")
        self.assertEqual(
            exc_context.exception.code,
            2,
            "Wrong `runpy` exit status code",
        )

    def test_cli_exit_code(self):
        """
        The command line script exits with status code zero if there are no exceptions.
        """
        # Find the location of the `console_scripts` for this test environment
        prefix_path = pathlib.Path(sys.argv[0]).parent
        while not (prefix_path / "bin").is_dir():
            prefix_path = prefix_path.parent
            if prefix_path.parent is list(prefix_path.parents)[-1]:  # pragma: no cover
                raise ValueError(f"Could not find script prefix path: {sys.argv[0]}")

        script_process = subprocess.run(  # nosec B603
            [prefix_path / "bin" / "project-structure", "foobar"],
            check=False,
        )
        self.assertEqual(
            script_process.returncode,
            0,
            "Running the console script exited with non-zero status code",
        )
