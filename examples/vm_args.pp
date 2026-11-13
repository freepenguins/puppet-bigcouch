# BigCouch with more Erlang VM arguments: a higher process limit and a
# shorter net tick time.
class { 'bigcouch':
  vm_args => ['+P 1048576', '-kernel net_ticktime 30'],
}
