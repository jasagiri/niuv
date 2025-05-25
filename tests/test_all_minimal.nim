# Minimal test_all.nim that runs a subset of tests
import unittest
import test_fs_utils
import test_power_assert

when isMainModule:
  echo "Running minimal test suite..."