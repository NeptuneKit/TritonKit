import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "docs-linhay/scripts/install-public-skills.sh"
SKILLS = ["tritonkit-dev-feedback", "tritonkit-emulator-cli-takeover", "tritonkit-real-project-regression", "tritonkit-update"]
spec = importlib.util.spec_from_file_location("triton_install_public_skills", SCRIPT.with_suffix(".py"))
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)

class InstallSkillsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.destination = self.root / "agent"
    def bundle(self, name="valid.tar.gz", text="version one", unsafe=False):
        path = self.root / name
        with tarfile.open(path, "w:gz") as tar:
            entries = {f"TritonKit.skills/{s}/SKILL.md": f"---\nname: {s}\n---\n{text}\n" for s in SKILLS}
            entries["TritonKit.skills/BUILD_INFO.json"] = json.dumps({"name":"tritonkit-skills", "version":"0.1.1", "bundlePath":"TritonKit.skills/"})
            if unsafe: entries["../escaped"] = "bad"
            for name, value in entries.items():
                data=value.encode(); info=tarfile.TarInfo(name); info.size=len(data)
                tar.addfile(info,io.BytesIO(data))
        return path
    def run_install(self, archive, *args, destination=None):
        return subprocess.run([str(SCRIPT),str(destination or self.destination),"--from-tar",str(archive),*args],capture_output=True,text=True)
    def install_args(self, archive):
        return SimpleNamespace(agent_skills_dir=str(self.destination), from_tar=str(archive), sha256=None, dry_run=False)
    def test_missing_archive_preserves_current_and_legacy(self):
        old=self.destination/"TritonKit.skills";old.mkdir(parents=True);(old/"keep").write_text("local")
        legacy=self.destination/SKILLS[0];legacy.mkdir();(legacy/"keep").write_text("legacy")
        result=self.run_install(self.root/"absent")
        self.assertNotEqual(result.returncode,0)
        self.assertEqual((old/"keep").read_text(),"local")
        self.assertTrue((legacy/"keep").exists())
    def test_archive_traversal_rejected_before_publication(self):
        result=self.run_install(self.bundle(unsafe=True))
        self.assertNotEqual(result.returncode,0)
        self.assertFalse((self.root/"escaped").exists())
        self.assertFalse((self.destination/"TritonKit.skills").exists())
    def test_local_changes_fail_closed(self):
        self.assertEqual(self.run_install(self.bundle()).returncode,0)
        target=self.destination/"TritonKit.skills"/SKILLS[0]/"SKILL.md"
        target.write_text("my local edit")
        result=self.run_install(self.bundle("next.tar.gz",text="version two"))
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(target.read_text(),"my local edit")
    def test_dry_run_has_no_destination_effects(self):
        result=self.run_install(self.bundle(),"--dry-run")
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(self.destination.exists())
    def test_clean_update_backups_and_private_permissions(self):
        self.assertEqual(self.run_install(self.bundle()).returncode,0)
        result=self.run_install(self.bundle("next.tar.gz",text="version two"))
        self.assertEqual(result.returncode,0,result.stderr)
        target=self.destination/"TritonKit.skills"/SKILLS[0]/"SKILL.md"
        self.assertIn("version two",target.read_text())
        self.assertEqual(target.stat().st_mode & 0o777,0o600)
        backups=list(self.destination.glob(".triton-skills-backup-*"))
        self.assertEqual(len(backups),1)
        self.assertIn("version one",(backups[0]/SKILLS[0]/"SKILL.md").read_text())
    def test_symlink_root_rejected(self):
        real=self.root/"real";real.mkdir();self.destination.symlink_to(real,target_is_directory=True)
        result=self.run_install(self.bundle())
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(list(real.iterdir()),[])
    def test_archive_symlink_rejected_before_installation(self):
        archive=self.bundle()
        alias=self.root/"archive-link.tar.gz";alias.symlink_to(archive)
        result=self.run_install(alias)
        self.assertNotEqual(result.returncode,0,result.stdout)
        self.assertFalse(self.destination.exists())
    def test_source_parent_symlink_rejected(self):
        archive=self.bundle()
        alias=self.root/"source-link";alias.symlink_to(self.root,target_is_directory=True)
        result=self.run_install(alias/archive.name)
        self.assertNotEqual(result.returncode,0,result.stdout)
        self.assertFalse(self.destination.exists())
    def test_destination_parent_symlink_rejected(self):
        real=self.root/"real-parent";real.mkdir()
        alias=self.root/"destination-link";alias.symlink_to(real,target_is_directory=True)
        result=self.run_install(self.bundle(),destination=alias/"agent")
        self.assertNotEqual(result.returncode,0,result.stdout)
        self.assertEqual(list(real.iterdir()),[])
    def test_raw_source_traversal_is_rejected(self):
        archive=self.bundle()
        child=self.root/"child";child.mkdir()
        alias=self.root/"source-link";alias.symlink_to(child,target_is_directory=True)
        for intermediate in (child,alias):
            with self.subTest(intermediate=intermediate.name):
                raw=intermediate/".."/archive.name
                result=self.run_install(raw)
                self.assertNotEqual(result.returncode,0,result.stdout)
                self.assertFalse(self.destination.exists())
    def test_raw_destination_traversal_is_rejected(self):
        archive=self.bundle()
        child=self.root/"child";child.mkdir()
        alias=self.root/"destination-link";alias.symlink_to(child,target_is_directory=True)
        for intermediate in (child,alias):
            with self.subTest(intermediate=intermediate.name):
                raw=intermediate/".."/"agent"
                result=self.run_install(archive,destination=raw)
                self.assertNotEqual(result.returncode,0,result.stdout)
                self.assertFalse(self.destination.exists())
    def test_current_edit_after_staging_rejected_without_deleting_edit(self):
        self.assertEqual(self.run_install(self.bundle()).returncode,0)
        archive=self.bundle("next.tar.gz",text="version two")
        target=self.destination/"TritonKit.skills"/SKILLS[0]/"SKILL.md"
        copytree=installer.shutil.copytree
        edited=[]
        def stage_then_edit(source,destination,*args,**kwargs):
            result=copytree(source,destination,*args,**kwargs)
            if Path(destination).name.startswith(".triton-skills-stage-"):
                target.write_text("user edit during staging")
                edited.append(target)
            return result
        with mock.patch.object(installer.shutil,"copytree",side_effect=stage_then_edit):
            with self.assertRaisesRegex(ValueError,"local skill modifications"):
                installer.install(self.install_args(archive))
        self.assertEqual(len(edited),1,"race must be injected after the incoming copy completes")
        self.assertEqual(target.read_text(),"user edit during staging")
        self.assertFalse((self.destination/".triton-skills-update.lock").exists())
        self.assertEqual(list(self.destination.glob(".triton-skills-stage-*")),[])
        self.assertEqual(list(self.destination.glob(".triton-skills-backup-*")),[])
    def test_failed_backup_rename_never_cleans_up_previous_installation(self):
        self.assertEqual(self.run_install(self.bundle()).returncode,0)
        archive=self.bundle("next.tar.gz",text="version two")
        rename=installer.os.rename
        attempted=[]
        def fail_backup(source,destination,*args,**kwargs):
            if Path(destination).name.startswith(".triton-skills-backup-"):
                attempted.append((Path(source),Path(destination)))
                raise OSError("injected backup publication failure")
            return rename(source,destination,*args,**kwargs)
        with mock.patch.object(installer.os,"rename",side_effect=fail_backup):
            with self.assertRaisesRegex(OSError,"injected backup publication failure"):
                installer.install(self.install_args(archive))
        self.assertEqual(len(attempted),1,"failure must follow an actual atomic exchange")
        retained=attempted[0][0]
        self.assertTrue(retained.is_dir(),"old installation at staging path must survive cleanup")
        self.assertIn("version one",(retained/SKILLS[0]/"SKILL.md").read_text())
        old_receipt=json.loads((retained/installer.MANIFEST).read_text())
        self.assertEqual(installer.hashes(retained),old_receipt["files"])
        current=self.destination/"TritonKit.skills"
        self.assertIn("version two",(current/SKILLS[0]/"SKILL.md").read_text())
        current_receipt=json.loads((current/installer.MANIFEST).read_text())
        self.assertEqual(installer.hashes(current),current_receipt["files"])
        self.assertFalse((self.destination/".triton-skills-update.lock").exists())
        self.assertEqual(list(self.destination.glob(".triton-skills-backup-*")),[])

if __name__ == "__main__": unittest.main()
