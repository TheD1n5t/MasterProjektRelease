# 2025-08-15T19:39:17.266705100
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/12343325.xsa")

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/ihopeitworks.xsa")

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

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

