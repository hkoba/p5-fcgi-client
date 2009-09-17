package FCGI::Client::Connection;
use Any::Moose;
use FCGI::Client::Constant;
use Time::HiRes qw(time);
use List::Util qw(max);
use POSIX qw(EAGAIN);
use FCGI::Client::Record;
use FCGI::Client::RecordFactory;
use Try::Tiny;

has sock => (
    is       => 'ro',
    required => 1,
);

has timeout => (
    is => 'ro',
    isa => 'Int',
    default => 10,
);

sub request {
    my ($self, $env, $content) = @_;
    local $SIG{PIPE} = "IGNORE";
    my $orig_alarm;
    my @res;
    try {
        $SIG{ALRM} = sub { Carp::confess('REQUESET_TIME_OUT') };
        $orig_alarm = alarm($self->timeout);
        $self->_send_request($env, $content);
        @res = $self->_receive_response($self->sock);
    } catch {
        if ($@) {
            die $@;
        } else {
            return @res;
        }
    };
}

sub _receive_response {
    my ($self, $sock) = @_;
    my ($stdout, $stderr);
    while (my $res = $self->_read_record($self)) {
        my $type = $res->type;
        if ($type == FCGI_STDOUT) {
            $stdout .= $res->content;
        } elsif ($type == FCGI_STDERR) {
            $stderr .= $res->content;
        } elsif ($type == FCGI_END_REQUEST) {
            $sock->close();
            return ($stdout, $stderr);
        } else {
            die "unknown response type: " . $res->type;
        }
    }
    die 'connection breaked from server process?';
}
sub _send_request {
    my ($self, $env, $content) = @_;
    my $reqid = 1;
    $self->sock->print(FCGI::Client::RecordFactory->create_request($reqid, $env, $content));
}

sub _read_record {
    my ($self) = @_;
    my $HEADER_SIZE = &FCGI::Client::RecordHeader::SIZE;
    my $header_raw = '';
    while (length($header_raw) != $HEADER_SIZE) {
        $self->_read_timeout(\$header_raw, $HEADER_SIZE-length($header_raw), length($header_raw)) or return;
    }
    my $header = FCGI::Client::RecordHeader->new(raw => $header_raw);
    my $content_length = $header->content_length;
    my $content = '';
    if ($content_length != 0) {
        while (length($content) != $content_length) {
            $self->_read_timeout(\$content, $content_length-length($content), length($content)) or return;
        }
    }
    my $padding_length = $header->padding_length;
    my $padding = '';
    if ($padding_length != 0) {
        while (length($padding) != $padding_length) {
            $self->_read_timeout(\$padding, $padding_length, 0) or return;
        }
    }
    return FCGI::Client::Record->new(
        header     => $header,
        content    => $content,
    );
}

# returns 1 if socket is ready, undef on timeout
sub _wait_socket {
    my ( $self, $sock, $is_write, $wait_until ) = @_;
    do {
        my $vec = '';
        vec( $vec, $sock->fileno, 1 ) = 1;
        if (
            select(
                $is_write ? undef : $vec,
                $is_write ? $vec  : undef,
                undef,
                max( $wait_until - time, 0 )
            ) > 0
          )
        {
            return 1;
        }
    } while ( time < $wait_until );
    return;
}

# returns (positive) number of bytes read, or undef if the socket is to be closed
sub _read_timeout {
    my ( $self, $buf, $len, $off, ) = @_;
    my $sock = $self->sock;
    my $timeout = $self->timeout;
    my $wait_until = time + $timeout;
    while ( $self->_wait_socket( $sock, undef, $wait_until ) ) {
        if ( my $ret = $sock->sysread( $$buf, $len, $off ) ) {
            return $ret;
        }
        elsif ( !( !defined($ret) && $! == EAGAIN ) ) {
            last;
        }
    }
    return;
}

1;
__END__

=head1 FAQ

=over 4

=item Why don't support FCGI_KEEP_CONN?

FCGI_KEEP_CONN is not used by lighttpd's mod_fastcgi.c, and mod_fast_cgi for apache.
And, FCGI.xs doesn't support it.

I seems FCGI_KEEP_CONN is not used in real world.

=back
