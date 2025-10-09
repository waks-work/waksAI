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
