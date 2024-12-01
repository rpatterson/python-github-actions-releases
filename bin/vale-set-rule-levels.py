#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

"""
Set all Vale rules from `BasedOnStyles` to the given level.

Make no change for any existing rules specified in the same section.
"""

import sys
import pathlib
import argparse

import yaml
import configobj

arg_parser = argparse.ArgumentParser(
    description=__doc__.strip(),
)
arg_parser.add_argument(
    "--input",
    "-i",
    dest="input_",
    type=argparse.FileType(),
    default=".vale.ini",
    help="The source Vale configuration file. (default: `./.vale.ini`)",
)
arg_parser.add_argument(
    "--output",
    "-o",
    help="The target Vale configuration file. (default: same as `--input`)",
)
arg_parser.add_argument(
    "--level",
    "-l",
    choices=["suggestion", "warning", "error"],
    default="error",
    help="Alert level to set for unset rules. (default: `error`)",
)


def main(args=None):  # pylint: disable=missing-function-docstring
    parsed_args = arg_parser.parse_args(args=args)

    config = configobj.ConfigObj(parsed_args.input_, list_values=False)
    parsed_args.input_.close()
    styles_dir = pathlib.Path(parsed_args.input_.name).parent / config["StylesPath"]
    for format_pattern in config.sections:
        format_settings = config[format_pattern]
        styles_value = format_settings.get("BasedOnStyles", "").strip()
        if not styles_value:
            continue
        for style in styles_value.split(","):
            style = style.strip()
            if style == "Vale":
                # TODO: Include the styles built into Vale itself:
                continue
            rules = {
                f"{style}.{rule_path.stem}": rule_path
                for rule_path in (styles_dir / style).glob("*.[yY][mM][lL]")
            }
            # Remove rules that a no longer in the style:
            for rule_name in format_settings:
                if rule_name.startswith(f"{style}.") and rule_name not in rules:
                    del format_settings[rule_name]
            # Specify the default level for rules not already in the format section:
            for rule_name, rule_path in rules.items():
                with rule_path.open(encoding="utf-8") as rule_config_opened:
                    rule_config = yaml.safe_load(rule_config_opened)
                if (
                    rule_name not in format_settings
                    and rule_config.get("level", "warning") != parsed_args.level
                ):
                    format_settings[rule_name] = parsed_args.level

    output = parsed_args.output
    if output is None:
        output = parsed_args.input_.name
    config.filename = output
    config.write(parsed_args.output)
    sys.exit()


main.__doc__ = __doc__


if __name__ == "__main__":
    main()
