import osproc, streams, strutils

proc newSSH*(user, host, sshPath, shellmonPath: string): Process =
  return startProcess(sshPath, "/", [user & "@" & host, shellmonPath])

proc runOutputCode*(ssh: Process, command: string): (string, int) =
  assert ssh != nil
  var inputStream = ssh.inputStream()
  var outputStream = ssh.outputStream()
  inputStream.write(uint64 command.len)
  inputStream.write(command)
  inputStream.flush()

  result[1] = int outputStream.readUint64()
  let outputLen = int outputStream.readUint64()
  assert outputLen < 100000
  result[0] = outputStream.readStr(outputLen)

proc runOutput*(ssh: Process, command: string): string =
  let (output, code) = ssh.runOutputCode(command)
  if code != 0:
    echo output
    raise newException(ValueError, "Non zero code returned: " & $code)
  return output.strip()

proc run*(ssh: Process, command: string) =
  discard ssh.runOutput(command)

proc readFileCode*(ssh: Process, path: string): (string, int) =
  var inputStream = ssh.inputStream()
  var outputStream = ssh.outputStream()
  let command = "$$$read"
  inputStream.write(uint64 command.len)
  inputStream.write(command)
  inputStream.flush()
  inputStream.write(uint64 path.len)
  inputStream.write(path)
  inputStream.flush()

  result[1] = int outputStream.readUint64()
  let outputLen = int outputStream.readUint64()
  result[0] = outputStream.readStr(outputLen)


proc writeFileCode*(ssh: Process, path: string, data: string): int =
  var inputStream = ssh.inputStream()
  var outputStream = ssh.outputStream()
  let command = "$$$write"
  inputStream.write(uint64 command.len)
  inputStream.write(command)
  inputStream.flush()
  inputStream.write(uint64 path.len)
  inputStream.write(path)
  inputStream.flush()
  inputStream.write(uint64 data.len)
  inputStream.write(data)
  inputStream.flush()

  return int outputStream.readUint64()


proc readFile*(ssh: Process, path: string): string =
  let (output, code) = ssh.readFileCode(path)
  if code != 0:
    raise newException(ValueError, "Non zero code returned: " & $code)
  return output


proc writeFile*(ssh: Process, path: string, data: string) =
  let code = ssh.writeFileCode(path, data)
  if code != 0:
    raise newException(ValueError, "Non zero code returned: " & $code)


proc exit*(ssh: Process) =
  ssh.run("$$$exit")


when isMainModule:
  var ssh = newSSH("uesr", "localhost", "shellmon")
  echo ssh.runOutput("ls")
  echo ssh.runOutput("pwd")
  echo ssh.readFile("/p/guardmons/shellmon.nim")
  ssh.writeFile("/p/guardmons/test.txt", "hi there")
  ssh.exit()
