

# GOAL:
# do something useful
# make a series of http calls
# where one call's parameters depend on another call


begin

  ops
    .get_request('http://fakeurl.com/return?value=funtimes')
    .post_request(
      'http://fakeurl.com/expect?value=funtimes',
      { value: value(:funtimes) }
    )

end
