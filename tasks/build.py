from invoke import task
import sys
from tasks.core.utils import setup_logging
from tasks.core.BoxBuilder import BoxBuilder

ctx_options = {
    "hide": "out", 
    "warn": True
}

@task()
def list_box(ctx):
    ctx.run(
        "ls env/",
        hide="err",
    )

@task(
help={
    'box_name': 'The name of the box',
    'provider': 'Provider name. Ie: virtualbox, vmware',
    'steps': 'The step numbers to build. Ie: -s 2 -s 3',
    'since': 'The step number to build since. All following steps will be build'
}, 
iterable=['steps'],
optional=['steps', 'since', 'verbose'],)
def build_box(ctx, box_name, provider, steps=None, since=None, verbose=None):
    setup_logging(verbose)
    bb = BoxBuilder(ctx, box_name, provider, steps, since)
    bb.build()