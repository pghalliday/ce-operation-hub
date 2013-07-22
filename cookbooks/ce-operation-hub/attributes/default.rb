default[:ce_operation_hub][:repository] = "https://github.com/pghalliday/ce-operation-hub.git"
default[:ce_operation_hub][:destination] = "/opt/ce-operation-hub"
default[:ce_operation_hub][:user] = "ce-operation-hub"
default[:ce_operation_hub][:ce_front_end][:submit] = "4000"
default[:ce_operation_hub][:ce_engine][:stream] = "4001"
default[:ce_operation_hub][:ce_engine][:history] = "4002"
default[:ce_operation_hub][:ce_engine][:result] = "4003"
default[:ce_operation_hub][:ce_engine][:timeout] = "2000"

# dependency defaults
default[:nodejs][:install_method] = "package"
default[:git][:version] = "1.8.3"
default[:zeromq][:version] = "3.2.3"
default[:zeromq][:url] = "http://download.zeromq.org"
