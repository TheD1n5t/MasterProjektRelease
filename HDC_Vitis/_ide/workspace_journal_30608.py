# 2025-06-15T17:54:30.200678600
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../DEBUGMYPROJECT/design_2_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

client.delete_component(name="hdc_application")

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

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../MEMORIESFIXED/design_3_wrapper.xsa")

status = platform.build()

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

vitis.dispose()

