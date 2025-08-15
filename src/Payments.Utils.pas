unit Payments.Utils;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils;

function DateTimeToISO8601(const ADateTime: TDateTime): string;

implementation

function DateTimeToISO8601(const ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss".000Z"', ADateTime);
end;

end.

