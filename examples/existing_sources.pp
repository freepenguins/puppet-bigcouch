# BigCouch from whatever APT sources the server already has (for example a
# repository managed elsewhere in the control repository), without an admin.
# Anyone who reaches port 5984 is then an admin.
class { 'bigcouch': }
