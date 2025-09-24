# 2025-07-22T02:17:28.842845200
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/works.xsa")

status = platform.build()

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

