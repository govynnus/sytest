prepare "Helper method for syncing",
    provides => [qw( do_sync )],

    do => sub {
        provide do_sync => sub {
            my ( $user, %params ) = @_;
            do_request_json_for( $user,
                method  => "GET",
                uri     => "/v2_alpha/sync",
                params  => \%params,
            )
        };
        Future->done()
    };

test "Can sync",
    requires => [qw( do_sync sync_user can_create_filter )],

    check => sub {
        my ( $do_sync, $sync_user ) = @_;

        my $sync_filter;

        my $check_empty_sync = sub {
            my ( $body ) = @_;
            require_json_keys( $body, qw( rooms room_map presence next_batch ) );
            require_json_keys( my $rooms = $body->{rooms}, qw( default ));
            require_json_keys( $rooms->{default}, qw( joined invited archived ) );
        };

        matrix_create_filter( $sync_user, {
            room => { timeline => { limit => 10 } }
        })->then( sub {
            ( $sync_filter ) = @_;
            $do_sync->( $sync_user, filter => $sync_filter )
        })->then( sub {
            my ( $body ) = @_;
            $check_empty_sync->( $body );
            $do_sync->( $sync_user,
                filter => $sync_filter,
                since => $body->{next_batch},
            )
        })->then( sub {
            my ( $body ) = @_;
            $check_empty_sync->( $body );
            Future->done(1);
        })
    };