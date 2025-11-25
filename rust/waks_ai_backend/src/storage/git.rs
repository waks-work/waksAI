pub async fn commit(
    _key: &str,
    _value: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    Ok(())
}

#[allow(dead_code)]
pub async fn delete(_key: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    Ok(())
}

/* TODO!
*
*
use std::process::Command;
use std::str;

pub async fn commit(
    key: &str,
    value: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let file_path = format!(".git/ai/{}", key);
    tokio::fs::write(&file_path, value).await?;

    let status = Command::new("git")
        .args(&["add", &file_path])
        .status()
        .await?;

    if !status.success() {
        return Err("Git add failed".into());
    }

    let output = Command::new("git")
        .args(&["commit", "-m", &format!("Update {}", key)])
        .output()
        .await?;

    if !output.status.success() {
        return Err(format!("Git commit failed: {}", str::from_utf8(&output.stderr)?).into());
    }

    Ok(())
}

#[allow(dead_code)]
pub async fn delete(key: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let file_path = format!(".git/ai/{}", key);

    let status = Command::new("git")
        .args(&["rm", "--cached", &file_path])
        .status()
        .await?;

    if !status.success() {
        return Err("Git rm failed".into());
    }

    let output = Command::new("git")
        .args(&["commit", "-m", &format!("Remove {}", key)])
        .output()
        .await?;

    if !output.status.success() {
        return Err(format!("Git commit failed: {}", str::from_utf8(&output.stderr)?).into());
    }

    // Delete the actual file
    tokio::fs::remove_file(&file_path).await?;

    Ok(())
}
*
*  */
