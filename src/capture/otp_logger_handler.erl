-module(otp_logger_handler).

-export([
    init_hawk_otp_logger_handler/0,
    adding_handler/1,
    removing_handler/1,
    log/2
]).

% 
% https://www.erlang.org/doc/apps/kernel/logger.html
% 
% pub type LogLevel {
%   Debug
%   Info
%   Notice
%   Warning
%   Error
%   Critical
%   Alert
%   Emergency
%   Off
% }

init_hawk_otp_logger_handler() ->
    case logger:get_handler_config(hawk_logger) of
        {ok, _Config} ->
            {ok, nil};

        {error, _} ->
            add_hawk_logger_handler()
    end.

add_hawk_logger_handler() ->
    case logger:add_handler(
        hawk_logger,
        ?MODULE,
        #{level => error}
    ) of
        ok ->
            {ok, nil};

        {error, {already_exist, _Id}} ->
            {ok, nil};

        {error, {already_exists, _Id}} ->
            {ok, nil};

        {error, Reason} ->
            {
                error,
                unicode:characters_to_binary(
                    io_lib:format("~p", [Reason])
                )
            }
    end.

adding_handler(Config) ->
    {ok, Config}.

removing_handler(_Config) ->
    ok.

%% OTP Logger sends each event to this callback.
log(#{msg := Message, meta := Meta}, _Config) ->
    try
        Title = format_log_message(Message, Meta),
        case is_hawk_event(Title) of
            true ->
                ok;
            false ->
                %% capture/otp_event.gleam is compiled as capture@otp_event.
                'capture@otp_event':capture(Title, <<"error">>),
                ok
        end
    catch
        _:_ ->
            ok
    end;

log(_LogEvent, _Config) ->
    ok.

is_hawk_event(Title) when is_binary(Title) ->
    case Title of
        <<"[Hawk]", _/binary>> -> true;
        _ -> false
    end;
is_hawk_event(_) ->
    false.

%% Plain text message.
format_log_message({string, Message}, _Meta) ->
    unicode:characters_to_binary(Message);

%% Match OTP/SASL reports before the generic {Format, Args} tuple.
format_log_message(
    {report, Report},
    #{domain := [otp, sasl | _]}
) ->
    format_crash_report(Report);

%% Any other report.
format_log_message({report, Report}, _Meta) ->
    format_report_fallback(Report);

%% Format string + arguments.
format_log_message({Format, Args}, _Meta) ->
    unicode:characters_to_binary(
        io_lib:format(Format, Args)
    ).

format_crash_report(#{report := Report}) ->
    format_crash_report(Report);

%% Try to extract the process crash reason.
format_crash_report([Crasher | _Neighbours] = Report) ->
    case lists:keyfind(error_info, 1, Crasher) of
        {error_info, {_Class, Reason, _Stacktrace}} ->
            unicode:characters_to_binary(
                io_lib:format("Process crashed: ~p", [Reason])
            );

        false ->
            format_report_fallback(Report)
    end;

%% Format an unexpected report structure in full.
format_crash_report(Report) ->
    format_report_fallback(Report).

%% Shared fallback for reports.
format_report_fallback(Report) ->
    {Format, Args} = logger:format_report(Report),

    unicode:characters_to_binary(
        io_lib:format(Format, Args)
    ).