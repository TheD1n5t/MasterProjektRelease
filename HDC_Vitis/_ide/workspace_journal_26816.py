# 2025-06-17T22:11:18.041096800
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../0003/design_1_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

