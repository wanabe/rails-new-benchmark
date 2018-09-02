def ll(obj, name, mod: nil, s: 0)
  if mod
    msg = "#{mod}##{name}"
    meth = mod.instace_method(name)
  else
    msg = "#{obj}.#{name}"
    meth = obj.method(name)
  end
  s.times do
    meth = meth.super_method
  end
  STDERR.puts msg, meth, meth.source_location
  raise Interrupt
end

def call_app
  response = @app.get("/", {})
  raise "Bad request: #{ response.body }" unless response.status == 200
  response
end

# Sandbox to overwrite the methods

begin
  require Rails.root.join("override.rb").to_s
rescue LoadError
end
