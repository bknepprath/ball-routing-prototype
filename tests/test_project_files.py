from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_project_layout() -> None:
    assert (ROOT / "project.godot").is_file()
    assert (ROOT / "main.tscn").is_file()
    assert (ROOT / "scripts" / "main.gd").is_file()
    assert (ROOT / "scripts" / "ball.gd").is_file()
    assert (ROOT / "scripts" / "attachment.gd").is_file()
    for asset_name in ("ballworks_structure", "finish_frame", "wood_beam"):
        assert (ROOT / "assets" / f"{asset_name}.glb").is_file()
        assert (ROOT / "blender" / "sources" / f"{asset_name}.blend").is_file()
        assert not (ROOT / "assets" / f"{asset_name}.blend").exists()
    assert (ROOT / "blender" / "create_wood_beam_asset.py").is_file()
    assert (ROOT / "blender" / "create_finish_frame_asset.py").is_file()
    assert (ROOT / "tests" / "test_level_chain_runtime.gd").is_file()
    assert (ROOT / "tests" / "test_end_to_end_runtime.gd").is_file()
    assert (ROOT / "tests" / "test_ball_load_runtime.gd").is_file()
    assert (ROOT / "tests" / "test_traversability_stress.gd").is_file()
    assert (ROOT / "tests" / "test_multi_ball_flow_runtime.gd").is_file()
    text = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")
    for token in (
        "_spawn_ball",
        "_on_stop_body_entered",
        "_on_payment_body_entered",
        "_buy_spawn_upgrade",
        "_buy_damage_upgrade",
        "_update_camera",
        "Color(\"c92d3b\")",
        "finish_frame.glb",
        "wood_beam.glb",
        "SmoothSerpentineHalfPipe",
        "ConveyorArea",
        "MAX_BALL_SHADOWS",
    ):
        assert token in text
    assert "chain_to" in (ROOT / "scripts" / "attachment.gd").read_text(encoding="utf-8")


if __name__ == "__main__":
    test_project_layout()
    print("project layout ok")
