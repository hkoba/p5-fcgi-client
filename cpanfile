requires 'perl', 5.008_001;
requires 'IO::Socket::UNIX';

requires 'Time::HiRes';
requires 'List::Util';

requires 'Moo';
requires 'Types::Standard';

on test => sub {
  requires 'File::Temp';
  requires 'autodie';
};
