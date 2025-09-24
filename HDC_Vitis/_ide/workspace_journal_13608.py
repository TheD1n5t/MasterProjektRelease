# 2025-08-29T08:24:21.932489
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/newmemories.xsa")

status = platform.build()

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

