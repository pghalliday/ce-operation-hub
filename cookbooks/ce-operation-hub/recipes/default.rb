include_recipe "nodejs"
include_recipe "git"
include_recipe "zeromq"

user node[:ce_operation_hub][:user] do
end

git "#{node[:ce_operation_hub][:destination]}" do
  user node[:ce_operation_hub][:user]
  repository node[:ce_operation_hub][:repository]
  destination node[:ce_operation_hub][:destination]
  not_if { ::FileTest.exists?(node[:ce_operation_hub][:destination]) }
end

file "#{node[:ce_operation_hub][:destination]}/config.json" do
  owner node[:ce_operation_hub][:user]
  content <<-EOH
{
  "ce-front-end": {
    "submit": #{node[:ce_operation_hub][:ce_front_end][:submit]}
  },
  "ce-engine": {
    "stream": #{node[:ce_operation_hub][:ce_engine][:stream]},
    "history": #{node[:ce_operation_hub][:ce_engine][:history]},
    "result": #{node[:ce_operation_hub][:ce_engine][:result]},
    "timeout": #{node[:ce_operation_hub][:ce_engine][:timeout]}
  }
}
  EOH
end

bash "start ce-operation-hub server" do
  code <<-EOH
    su -l #{node[:ce_operation_hub][:user]} -c "cd #{node[:ce_operation_hub][:destination]} && npm install && npm start"
  EOH
end
