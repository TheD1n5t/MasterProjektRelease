# 2025-06-22T22:33:56.868058700
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/idk_wrap.xsa")

status = platform.build()

