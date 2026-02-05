///|
test "root API routes to spec platform dispatch" {
  let h = default_host()
  let id = h.id()
  let all = all_hosts()
  inspect(all.contains(id), content="true")
  let avail = available_hosts()
  if avail.length() > 0 {
    inspect(avail.contains(id), content="true")
  } else {
    // Unsupported target: allow an empty available host set.
    inspect(true, content="true")
  }
}
