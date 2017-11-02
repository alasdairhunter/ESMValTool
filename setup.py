#!/usr/bin/env python
"""ESMValTool installation script"""
# This script only installs dependencies available on PyPI
#
# Dependencies that need to be installed some other way (e.g. conda):
# - ncl
# - iris
# - python-stratify
# - basemap

import os
import re
import sys

from setuptools import Command, setup

PACKAGES = [
    'esmvaltool',
]


def discover_python_files(paths, ignore):
    """Discover Python files"""
    def _ignore(path):
        """Return True if `path` should be ignored, False otherwise."""
        return any(re.match(pattern, path) for pattern in ignore)

    for path in sorted(set(paths)):
        for root, _, files in os.walk(path):
            if _ignore(path):
                continue
            for filename in files:
                filename = os.path.join(root, filename)
                if (filename.lower().endswith('.py')
                        and not _ignore(filename)):
                    yield filename


class CustomCommand(Command):
    """Custom Command class"""

    def install_deps_temp(self):
        """Try to temporarily install packages needed to run the command."""
        if self.distribution.install_requires:
            self.distribution.fetch_build_eggs(
                self.distribution.install_requires)
        if self.distribution.tests_require:
            self.distribution.fetch_build_eggs(self.distribution.tests_require)


class RunTests(CustomCommand):
    """Class to run tests and generate reports."""

    user_options = []

    def initialize_options(self):
        """Do nothing"""

    def finalize_options(self):
        """Do nothing"""

    def run(self):
        """Run tests and generate a coverage report."""
        self.install_deps_temp()

        import pytest

        report_dir = 'test-reports'
        errno = pytest.main([
            'tests',
            '--ignore=tests/test_diagnostics',
            '--cov=esmvaltool',
            '--cov-report=term',
            '--cov-report=html:{}/coverage_html'.format(report_dir),
            '--cov-report=xml:{}/coverage.xml'.format(report_dir),
            '--junit-xml={}/report.xml'.format(report_dir),
            '--html={}/report.html'.format(report_dir),
        ])

        sys.exit(errno)


class RunLinter(CustomCommand):
    """Class to run a linter and generate reports."""

    user_options = []

    def initialize_options(self):
        """Do nothing"""

    def finalize_options(self):
        """Do nothing"""

    def run(self):
        """Run prospector and generate a report."""
        check_paths = PACKAGES + [
            'setup.py',
            'tests',
            'util',
        ]
        ignore = [
            'esmvaltool/doc/sphinx',
        ]

        # try to install missing dependencies and import prospector
        try:
            from prospector.run import main
        except ImportError:
            # try to install and then import
            self.distribution.fetch_build_eggs(['prospector[with_pyroma]'])
            from prospector.run import main

        self.install_deps_temp()

        # run linter

        # change working directory to package root
        package_root = os.path.abspath(os.path.dirname(__file__))
        os.chdir(package_root)

        # write command line
        files = discover_python_files(check_paths, ignore)
        sys.argv = ['prospector']
        sys.argv.extend(files)

        # run prospector
        errno = main()

        sys.exit(errno)


with open('README.md') as readme:
    setup(
        name='ESMValTool',
        version='2.0.0',
        description='Earth System Models eValuation Tool',
        long_description=readme.read(),
        url='https://www.esmvaltool.org',
        download_url='https://github.com/ESMValGroup/ESMValTool',
        license='Apache License, Version 2.0',
        classifiers=[
            'Environment :: Console',
            'License :: OSI Approved :: Apache Software License',
            'Programming Language :: Python',
            'Programming Language :: Python :: 2.7',
        ],
        packages=PACKAGES,
        # Include all version controlled files
        include_package_data=True,
        use_scm_version=True,
        setup_requires=[
            'setuptools_scm',
        ],
        install_requires=[
            'cdo',
            'cf_units',
            'coverage',
            'esgf-pyclient',
            'numpy',
            'netCDF4',
            'matplotlib',
            'pyyaml',
            'shapely',
            'pillow',
        ],
        tests_require=[
            # TODO: add dummydata package once up to date PyPI version
            'easytest',
            'mock',
            'nose',
            'pycodestyle',
            'pytest',
            'pytest-cov',
            'pytest-html',
        ],
        entry_points={
            'console_scripts': [
                'esmvaltool = esmvaltool.main:run',
            ],
        },
        cmdclass={
            'test': RunTests,
            'lint': RunLinter,
        },
        zip_safe=False,
    )