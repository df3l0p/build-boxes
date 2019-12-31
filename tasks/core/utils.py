import logging

def setup_logging(verbose, default_verbosity = logging.INFO):
    verbosity = default_verbosity
    if verbose is not None:
        verbosity = logging.DEBUG
    logging.getLogger().setLevel(verbosity)