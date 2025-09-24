# 2025-06-08T00:09:39.434665200
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
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

status = platform.update_hw(hw_design = "C:\Users\Krischan\Downloads\HDC_VIVADO_AMFIXED\design_1_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

client.delete_component(name="hdc_application")

comp = client.create_app_component(name="hdc_application",platform = "$COMPONENT_LOCATION/../hdc_platform/export/hdc_platform/hdc_platform.xpfm",domain = "standalone_psu_cortexa53_0")

comp = client.get_component(name="hdc_application")
status = comp.import_files(from_loc="C:\Users\Krischan\Desktop", files=["main.c", "vectors_data.c", "vectors_data.h"], dest_dir_in_cmp = "src")

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

