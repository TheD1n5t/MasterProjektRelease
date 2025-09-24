# 2025-06-26T19:14:00.456527800
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.build()

comp.build()

vitis.dispose()

