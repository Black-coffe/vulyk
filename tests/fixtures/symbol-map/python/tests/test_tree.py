import os


def test_every_file_is_named():
    for _dirpath, _dirs, names in os.walk('.'):
        assert all(names)
