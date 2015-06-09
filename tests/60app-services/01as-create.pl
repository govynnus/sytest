test "AS can create a user",
   requires => [qw( do_request_json_for as_user )],

   provides => [qw( make_as_user )],

   do => sub {
      my ( $do_request_json_for, $as_user ) = @_;

      $do_request_json_for->( $as_user,
         method => "POST",
         uri    => "/register",

         content => {
            type => "m.login.application_service",
            user => "astest-01create-1",
         },
      )->then( sub {
         my ( $body ) = @_;

         log_if_fail "Body", $body;

         require_json_keys( $body, qw( user_id home_server ));

         provide make_as_user => sub {
            my ( $user_id_fragment ) = @_;

            $do_request_json_for->( $as_user,
               method => "POST",
               uri    => "/register",

               content => {
                  type => "m.login.application_service",
                  user => "astest-$user_id_fragment"
               },
            )->then( sub {
               my ( $body ) = @_;

               # TODO: user has no event stream yet. Should they?
               Future->done(
                  User( $as_user->http, $body->{user_id}, $body->{access_token}, undef, [], undef )
               );
            });
         };

         Future->done(1);
      });
   };

test "AS cannot create users outside its own namespace",
   requires => [qw( do_request_json_for as_user expect_http_4xx )],

   do => sub {
      my ( $do_request_json_for, $as_user, $expect_http_4xx ) = @_;

      $do_request_json_for->( $as_user,
         method => "POST",
         uri    => "/register",

         content => {
            type => "m.login.application_service",
            user => "a-different-user",
         }
      )->$expect_http_4xx;
   };

test "Regular users cannot register within the AS namespace",
   requires => [qw( register_new_user first_http_client expect_http_4xx )],

   do => sub {
      my ( $register_new_user, $http, $expect_http_4xx ) = @_;

      $register_new_user->( $http, "astest-01create-2" )
         ->$expect_http_4xx;
   };

my $room_id;
prepare "Creating a new test room",
   requires => [qw( make_test_room user )],

   do => sub {
      my ( $make_test_room, $user ) = @_;

      $make_test_room->( $user )
         ->on_done( sub {
            ( $room_id ) = @_;
         });
   };

test "AS can make room aliases",
   requires => [qw( do_request_json_for as_user first_home_server
                    can_create_room can_create_room_alias )],

   do => sub {
      my ( $do_request_json_for, $as_user, $first_home_server ) = @_;
      my $room_alias = "#astest-01create-1:$first_home_server";

      $do_request_json_for->( $as_user,
         method => "PUT",
         uri    => "/directory/room/$room_alias",

         content => {
            room_id => $room_id,
         },
      )->then( sub {
         # Nothing interesting in the body

         $do_request_json_for->( $as_user,
            method => "GET",
            uri    => "/directory/room/$room_alias",
         )
      })->then( sub {
         my ( $body ) = @_;

         log_if_fail "Body", $body;

         require_json_keys( $body, qw( room_id ));

         $body->{room_id} eq $room_id or
            die "Expected 'room_id' to be $room_id'";

         Future->done(1);
      });
   };

test "Regular users cannot create room aliases within the AS namespace",
   requires => [qw( do_request_json first_home_server expect_http_4xx
                    can_create_room can_create_room_alias )],

   do => sub {
      my ( $do_request_json, $first_home_server, $expect_http_4xx ) = @_;
      my $room_alias = "#astest-01create-2:$first_home_server";

      $do_request_json->(
         method => "PUT",
         uri    => "/directory/room/$room_alias",

         content => {
            room_id => $room_id,
         }
      )->$expect_http_4xx;
   };
