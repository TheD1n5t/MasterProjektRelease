# 2025-06-04T13:11:36.395950300
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.create_platform_component(name = "hdc_platform",hw_design = "$COMPONENT_LOCATION/../../HDC_Top/design_1_wrapper.xsa",os = "standalone",cpu = "psu_cortexa53_0",domain_name = "standalone_psu_cortexa53_0")

comp = client.create_app_component(name="hdc_application",platform = "$COMPONENT_LOCATION/../hdc_platform/export/hdc_platform/hdc_platform.xpfm",domain = "standalone_psu_cortexa53_0")

platform = client.get_component(name="hdc_platform")
domain = platform.get_domain(name="zynqmp_fsbl")

status = domain.set_config(option = "os", param = "standalone_stdin", value = "psu_uart_1")

status = domain.set_config(option = "os", param = "standalone_stdout", value = "psu_uart_1")

domain = platform.get_domain(name="standalone_psu_cortexa53_0")

status = domain.set_config(option = "os", param = "standalone_stdin", value = "psu_uart_1")

status = domain.set_config(option = "os", param = "standalone_stdout", value = "psu_uart_1")

status = platform.build()

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

