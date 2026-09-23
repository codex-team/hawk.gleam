-module(transport_ffi).
-export([configure/1, send/2]).

-define(PROFILE, hawk_gleam).
-define(REQUEST_TIMEOUT_MS, 30_000).
-define(CONNECT_TIMEOUT_MS, 5_000).

configure(Limit) when is_integer(Limit), Limit > 0 ->
    case application:ensure_all_started(ssl) of
        {ok, _} ->
            case application:ensure_all_started(inets) of
                {ok, _} ->
                    configure_profile(Limit);
                {error, _} ->
                    {error, nil}
            end;
        {error, _} ->
            {error, nil}
    end.

configure_profile(Limit) ->
    case ensure_profile() of
        ok ->
            case httpc:set_options(connection_options(Limit), ?PROFILE) of
                ok -> {ok, nil};
                {error, _} -> {error, nil}
            end;
        {error, _} ->
            {error, nil}
    end.

ensure_profile() ->
    case inets:start(httpc, [{profile, ?PROFILE}]) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok;
        Error -> Error
    end.

connection_options(Limit) ->
    Base = [{max_sessions, Limit}],
    case list_to_integer(erlang:system_info(otp_release)) >= 29 of
        true -> [{max_connections_open, Limit} | Base];
        false -> Base
    end.

send(Url, Body) when is_binary(Url), is_binary(Body) ->
    Request = {
        binary_to_list(Url),
        [{"content-type", "application/json"}],
        "application/json",
        Body
    },
    HttpOptions = [
        {timeout, ?REQUEST_TIMEOUT_MS},
        {connect_timeout, ?CONNECT_TIMEOUT_MS},
        {ssl, [
            {verify, verify_peer},
            {cacerts, public_key:cacerts_get()}
        ]}
    ],
    Options = [{body_format, binary}],
    case httpc:request(post, Request, HttpOptions, Options, ?PROFILE) of
        {ok, {{_Version, Status, _Reason}, _Headers, _Body}}
          when is_integer(Status) ->
            {ok, Status};
        {error, _} ->
            {error, nil}
    end.
