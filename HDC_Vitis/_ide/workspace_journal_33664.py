# 2025-06-09T17:28:03.217921
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

client.delete_component(name="hdc_application")

client.delete_component(name="hdc_platform")

platform = client.create_platform_component(name = "hdc_platform",hw_design = "C:\Users\Krischan\Downloads\HDC_IP_VITIS\design_1_wrapper.xsa",os = "standalone",cpu = "psu_cortexa53_0",domain_name = "standalone_psu_cortexa53_0")

platform = client.get_component(name="hdc_platform")
status = platform.build()

domain = platform.get_domain(name="zynqmp_fsbl")

status = domain.set_config(option = "os", param = "standalone_stdin", value = "psu_uart_1")

status = domain.set_config(option = "os", param = "standalone_stdout", value = "psu_uart_1")

domain = platform.get_domain(name="standalone_psu_cortexa53_0")

status = domain.set_config(option = "os", param = "standalone_stdin", value = "psu_uart_1")

status = domain.set_config(option = "os", param = "standalone_stdout", value = "psu_uart_1")

status = platform.build()

comp = client.create_app_component(name="hdc_application",platform = "$COMPONENT_LOCATION/../hdc_platform/export/hdc_platform/hdc_platform.xpfm",domain = "standalone_psu_cortexa53_0")

comp = client.get_component(name="hdc_application")
status = comp.import_files(from_loc="C:\Users\Krischan\Desktop", files=["main.c", "vectors_data.c", "vectors_data.h"], dest_dir_in_cmp = "src")

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "C:\Users\Krischan\Downloads\HDC_ALLFIXED\design_1_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

client.delete_component(name="hdc_application")

client.delete_component(name="hdc_platform")

platform = client.create_platform_component(name = "hdc_platform",hw_design = "C:\Users\Krischan\Downloads\HDC_ALLFIXED\design_1_wrapper.xsa",os = "standalone",cpu = "psu_cortexa53_0",domain_name = "standalone_psu_cortexa53_0")

domain = platform.get_domain(name="zynqmp_fsbl")

status = domain.set_config(option = "os", param = "standalone_stdin", value = "psu_uart_1")

status = domain.set_config(option = "os", param = "standalone_stdout", value = "psu_uart_1")

domain = platform.get_domain(name="standalone_psu_cortexa53_0")

status = domain.set_config(option = "os", param = "standalone_stdin", value = "psu_uart_1")

status = domain.set_config(option = "os", param = "standalone_stdout", value = "psu_uart_1")

status = platform.build()

comp = client.create_app_component(name="hdc_application",platform = "$COMPONENT_LOCATION/../hdc_platform/export/hdc_platform/hdc_platform.xpfm",domain = "standalone_psu_cortexa53_0")

comp = client.get_component(name="hdc_application")
status = comp.import_files(from_loc="C:\Users\Krischan\Desktop", files=["main.c", "vectors_data.c", "vectors_data.h"], dest_dir_in_cmp = "hdc_application")

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

vitis.dispose()

