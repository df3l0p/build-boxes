from invoke import Collection
from . import build

ns = Collection()
ns.add_collection(build)