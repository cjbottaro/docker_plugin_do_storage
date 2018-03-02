use Mix.Config

config :do_storage,
  access_token: "123abc",
  region: "nyc1",
  sleep: 0,
  file: FileMock,
  system: SystemMock,
  http: HttpMock
